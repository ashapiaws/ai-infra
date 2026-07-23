"""
Distributed Data Parallel (DDP) Training Script
Network Topology Testing — 3 Node Training Job

Measures throughput (samples/sec) and communication overhead
to quantify impact of network topology on all-reduce performance.

Usage (via torchrun):
  torchrun --nnodes=3 --nproc_per_node=8 ... train.py \
    --topology-mode=same-spine \
    --run-id=same-spine-20250101-120000
"""

import os
import time
import json
import socket
import argparse
from datetime import datetime

import torch
import torch.nn as nn
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader, DistributedSampler
from torchvision import models, datasets, transforms
from prometheus_client import start_http_server, Gauge, Histogram


# ─── Metrics ────────────────────────────────────────────────────────────────────

STEP_TIME = Histogram(
    "training_step_time_seconds",
    "Time per training step (forward + backward + sync)",
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5],
)
COMM_TIME = Histogram(
    "training_comm_time_seconds",
    "Time spent in all-reduce synchronization per step",
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25],
)
THROUGHPUT = Gauge(
    "training_throughput_samples_per_second",
    "Global training throughput in samples per second",
)
GPU_UTIL = Gauge(
    "training_gpu_utilization_percent",
    "GPU utilization percentage",
)


# ─── Config ─────────────────────────────────────────────────────────────────────

class TrainingConfig:
    """Training configuration — adjust for your topology test."""

    # Model
    model_name: str = "resnet152"  # Good gradient volume, fits single L40S (48GB VRAM)
    num_classes: int = 1000

    # Training
    batch_size: int = 64           # Per-GPU batch size (L40S has 48GB VRAM)
    num_steps: int = 500           # Steps per run (enough for stable measurement)
    warmup_steps: int = 20         # Discard warmup from metrics
    learning_rate: float = 0.01
    input_size: int = 224          # Standard ImageNet input size

    # Synthetic data (avoids I/O as bottleneck)
    use_synthetic_data: bool = True

    # Metrics
    prometheus_port: int = 8000
    log_interval: int = 10         # Log every N steps


# ─── Synthetic Dataset ──────────────────────────────────────────────────────────

class SyntheticDataset(torch.utils.data.Dataset):
    """Generates random tensors to isolate compute/comm from I/O."""

    def __init__(self, size: int, input_size: int, num_classes: int):
        self.size = size
        self.input_size = input_size
        self.num_classes = num_classes

    def __len__(self):
        return self.size

    def __getitem__(self, idx):
        image = torch.randn(3, self.input_size, self.input_size)
        label = torch.randint(0, self.num_classes, (1,)).item()
        return image, label


# ─── Training Loop ──────────────────────────────────────────────────────────────

def setup_distributed():
    """Initialize distributed process group."""
    dist.init_process_group(backend="nccl")
    local_rank = int(os.environ.get("LOCAL_RANK", 0))
    torch.cuda.set_device(local_rank)
    return local_rank


def get_model(config: TrainingConfig, local_rank: int) -> DDP:
    """Create model and wrap with DDP."""
    model = getattr(models, config.model_name)(num_classes=config.num_classes)
    model = model.cuda(local_rank)
    model = DDP(model, device_ids=[local_rank])
    return model


def get_dataloader(config: TrainingConfig) -> DataLoader:
    """Create dataloader with synthetic data."""
    dataset = SyntheticDataset(
        size=config.batch_size * config.num_steps * 2,
        input_size=config.input_size,
        num_classes=config.num_classes,
    )
    sampler = DistributedSampler(dataset)
    return DataLoader(
        dataset,
        batch_size=config.batch_size,
        sampler=sampler,
        num_workers=4,
        pin_memory=True,
    )


def train(config: TrainingConfig, topology_mode: str = "unknown", run_id: str = ""):
    """Main training loop with metric collection."""
    local_rank = setup_distributed()
    rank = dist.get_rank()
    world_size = dist.get_world_size()

    if rank == 0:
        start_http_server(config.prometheus_port)
        print(f"\n{'='*60}")
        print(f" TOPOLOGY TRAINING TEST — {topology_mode.upper()}")
        print(f"{'='*60}")
        print(f"[Rank 0] Run ID: {run_id}")
        print(f"[Rank 0] Topology Mode: {topology_mode}")
        print(f"[Rank 0] Node Group: {os.environ.get('NODE_GROUP', 'unknown')}")
        print(f"[Rank 0] World size: {world_size}")
        print(f"[Rank 0] Hostname: {socket.gethostname()}")
        print(f"[Rank 0] Node Name: {os.environ.get('NODE_NAME', 'unknown')}")
        print(f"[Rank 0] Model: {config.model_name}")
        print(f"[Rank 0] Batch size (per GPU): {config.batch_size}")
        print(f"[Rank 0] Total batch size: {config.batch_size * world_size}")
        print(f"[Rank 0] Steps: {config.num_steps}")
        print(f"{'='*60}\n")

    model = get_model(config, local_rank)
    optimizer = torch.optim.SGD(model.parameters(), lr=config.learning_rate, momentum=0.9)
    criterion = nn.CrossEntropyLoss().cuda(local_rank)
    dataloader = get_dataloader(config)

    # Metrics collection
    step_times = []
    comm_times = []
    throughputs = []

    model.train()
    data_iter = iter(dataloader)

    for step in range(config.num_steps):
        try:
            images, labels = next(data_iter)
        except StopIteration:
            data_iter = iter(dataloader)
            images, labels = next(data_iter)

        images = images.cuda(local_rank, non_blocking=True)
        labels = labels.cuda(local_rank, non_blocking=True)

        # ── Forward + Backward (compute) ──
        torch.cuda.synchronize()
        step_start = time.perf_counter()

        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)

        # Time the backward pass (includes all-reduce via DDP hooks)
        torch.cuda.synchronize()
        comm_start = time.perf_counter()

        loss.backward()  # DDP all-reduce happens here

        torch.cuda.synchronize()
        comm_end = time.perf_counter()

        optimizer.step()

        torch.cuda.synchronize()
        step_end = time.perf_counter()

        # ── Metrics ──
        step_time = step_end - step_start
        comm_time = comm_end - comm_start  # Approximation: backward includes compute + comm

        if step >= config.warmup_steps:
            step_times.append(step_time)
            comm_times.append(comm_time)

            samples_per_sec = (config.batch_size * world_size) / step_time
            throughputs.append(samples_per_sec)

            # Prometheus metrics
            STEP_TIME.observe(step_time)
            COMM_TIME.observe(comm_time)
            THROUGHPUT.set(samples_per_sec)

        if rank == 0 and step % config.log_interval == 0:
            samples_per_sec = (config.batch_size * world_size) / step_time
            print(
                f"[Step {step:4d}/{config.num_steps}] "
                f"loss={loss.item():.4f} "
                f"step_time={step_time*1000:.1f}ms "
                f"comm_time={comm_time*1000:.1f}ms "
                f"throughput={samples_per_sec:.1f} samples/s"
            )

    # ── Final Summary ──
    if rank == 0:
        avg_step = sum(step_times) / len(step_times) * 1000
        avg_comm = sum(comm_times) / len(comm_times) * 1000
        avg_throughput = sum(throughputs) / len(throughputs)
        p50_step = sorted(step_times)[len(step_times) // 2] * 1000
        p99_step = sorted(step_times)[int(len(step_times) * 0.99)] * 1000

        summary = {
            "timestamp": datetime.utcnow().isoformat(),
            "run_id": run_id,
            "topology_mode": topology_mode,
            "node_group": os.environ.get("NODE_GROUP", "unknown"),
            "hostname": socket.gethostname(),
            "node_name": os.environ.get("NODE_NAME", "unknown"),
            "world_size": world_size,
            "model": config.model_name,
            "batch_size_per_gpu": config.batch_size,
            "total_batch_size": config.batch_size * world_size,
            "num_steps": config.num_steps,
            "warmup_steps": config.warmup_steps,
            "avg_step_time_ms": round(avg_step, 2),
            "p50_step_time_ms": round(p50_step, 2),
            "p99_step_time_ms": round(p99_step, 2),
            "avg_comm_time_ms": round(avg_comm, 2),
            "avg_throughput_samples_per_sec": round(avg_throughput, 2),
            "comm_compute_ratio": round(avg_comm / avg_step, 4),
        }

        print("\n" + "=" * 60)
        print("TRAINING TOPOLOGY TEST — RESULTS SUMMARY")
        print("=" * 60)
        for k, v in summary.items():
            print(f"  {k}: {v}")
        print("=" * 60)

        # Write results to file for post-analysis
        results_file = f"/workspace/results/results-{topology_mode}-{run_id}.json"
        with open(results_file, "w") as f:
            json.dump(summary, f, indent=2)
        print(f"\n  Results written to: {results_file}")

    dist.destroy_process_group()


def parse_args():
    """Parse CLI arguments for topology test configuration."""
    parser = argparse.ArgumentParser(description="DDP Training - Network Topology Test")
    parser.add_argument(
        "--topology-mode",
        type=str,
        default=os.environ.get("TOPOLOGY_MODE", "unknown"),
        choices=["same-spine", "cross-spine", "multi-az", "unknown"],
        help="Topology placement mode (same-spine, cross-spine, multi-az)",
    )
    parser.add_argument(
        "--run-id",
        type=str,
        default=datetime.utcnow().strftime("%Y%m%d-%H%M%S"),
        help="Unique run identifier for result tracking",
    )
    parser.add_argument(
        "--num-steps",
        type=int,
        default=500,
        help="Number of training steps",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=32,
        help="Per-GPU batch size",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    config = TrainingConfig()
    config.num_steps = args.num_steps
    config.batch_size = args.batch_size
    train(config, topology_mode=args.topology_mode, run_id=args.run_id)

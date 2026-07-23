"""
EFA & NCCL Baseline Validation Script

Runs a series of checks to confirm:
  1. EFA devices are present and accessible
  2. NCCL can initialize across nodes
  3. All-reduce operations complete successfully
  4. Baseline bandwidth/latency numbers are sane

Uses the same container image as the training job.
"""

import os
import sys
import time
import subprocess
import socket
import json
from datetime import datetime

import torch
import torch.distributed as dist


def log(msg: str):
    rank = dist.get_rank() if dist.is_initialized() else -1
    print(f"[Rank {rank}][{socket.gethostname()}] {msg}", flush=True)


def check_efa_devices():
    """Verify EFA interfaces are visible."""
    log("=" * 60)
    log("CHECK 1: EFA Device Discovery")
    log("=" * 60)

    # Check for EFA devices via /sys
    efa_devices = []
    efa_path = "/sys/class/infiniband"
    if os.path.exists(efa_path):
        efa_devices = os.listdir(efa_path)
        log(f"  Found {len(efa_devices)} EFA device(s): {efa_devices}")
    else:
        log(f"  WARNING: {efa_path} not found")

    # Check fi_info for EFA provider
    try:
        result = subprocess.run(
            ["fi_info", "-p", "efa"],
            capture_output=True, text=True, timeout=10
        )
        efa_lines = [l for l in result.stdout.splitlines() if "provider:" in l]
        log(f"  fi_info EFA providers: {len(efa_lines)}")
        for line in efa_lines[:8]:  # Show first 8
            log(f"    {line.strip()}")

        if result.returncode != 0 or not efa_lines:
            log("  FAIL: No EFA provider found via fi_info")
            return False
    except FileNotFoundError:
        log("  WARNING: fi_info not available, skipping libfabric check")
    except subprocess.TimeoutExpired:
        log("  WARNING: fi_info timed out")

    if efa_devices:
        log("  PASS: EFA devices detected")
        return True
    else:
        log("  FAIL: No EFA devices found")
        return False


def check_nccl_init():
    """Verify NCCL initializes and all ranks connect."""
    log("")
    log("=" * 60)
    log("CHECK 2: NCCL Process Group Initialization")
    log("=" * 60)

    try:
        dist.init_process_group(backend="nccl")
        rank = dist.get_rank()
        world_size = dist.get_world_size()
        log(f"  NCCL initialized: rank={rank}, world_size={world_size}")

        # Barrier to confirm all nodes connected
        dist.barrier()
        log("  PASS: All ranks connected, barrier succeeded")
        return True
    except Exception as e:
        log(f"  FAIL: NCCL init failed: {e}")
        return False


def check_allreduce_correctness():
    """Verify all-reduce produces correct results."""
    log("")
    log("=" * 60)
    log("CHECK 3: All-Reduce Correctness")
    log("=" * 60)

    rank = dist.get_rank()
    world_size = dist.get_world_size()
    local_rank = int(os.environ.get("LOCAL_RANK", 0))

    # Each rank contributes its rank value; sum should be 0+1+...+(N-1)
    tensor = torch.tensor([float(rank)], device=f"cuda:{local_rank}")
    dist.all_reduce(tensor, op=dist.ReduceOp.SUM)

    expected = sum(range(world_size))
    actual = tensor.item()

    if abs(actual - expected) < 1e-5:
        log(f"  PASS: all_reduce(rank) = {actual} (expected {expected})")
        return True
    else:
        log(f"  FAIL: all_reduce(rank) = {actual} (expected {expected})")
        return False


def check_allreduce_bandwidth():
    """Measure all-reduce bandwidth at various message sizes."""
    log("")
    log("=" * 60)
    log("CHECK 4: All-Reduce Bandwidth Baseline")
    log("=" * 60)

    local_rank = int(os.environ.get("LOCAL_RANK", 0))
    world_size = dist.get_world_size()

    # Message sizes to test (bytes)
    sizes_mb = [1, 8, 32, 128, 256, 512]
    results = []

    for size_mb in sizes_mb:
        num_elements = (size_mb * 1024 * 1024) // 4  # float32
        tensor = torch.randn(num_elements, device=f"cuda:{local_rank}")

        # Warmup
        for _ in range(5):
            dist.all_reduce(tensor)
        torch.cuda.synchronize()

        # Timed runs
        num_iters = 20
        torch.cuda.synchronize()
        start = time.perf_counter()

        for _ in range(num_iters):
            dist.all_reduce(tensor)

        torch.cuda.synchronize()
        elapsed = time.perf_counter() - start

        # Bandwidth calculation (ring all-reduce: 2*(N-1)/N * size)
        algo_bw = (size_mb * num_iters) / elapsed  # MB/s
        bus_bw = algo_bw * (2 * (world_size - 1) / world_size)  # Bus bandwidth

        results.append({
            "size_mb": size_mb,
            "algo_bw_gbps": round(algo_bw * 8 / 1000, 2),  # Convert MB/s to Gbps
            "bus_bw_gbps": round(bus_bw * 8 / 1000, 2),
            "avg_latency_ms": round((elapsed / num_iters) * 1000, 3),
        })

        log(f"  {size_mb:4d} MB | algo_bw: {results[-1]['algo_bw_gbps']:7.2f} Gbps | "
            f"bus_bw: {results[-1]['bus_bw_gbps']:7.2f} Gbps | "
            f"latency: {results[-1]['avg_latency_ms']:.3f} ms")

    log("  PASS: All-reduce bandwidth test complete")
    return results


def check_p2p_bandwidth():
    """Measure point-to-point send/recv bandwidth between rank 0 and rank 1."""
    log("")
    log("=" * 60)
    log("CHECK 5: Point-to-Point Bandwidth (Rank 0 <-> Rank 1)")
    log("=" * 60)

    rank = dist.get_rank()
    world_size = dist.get_world_size()
    local_rank = int(os.environ.get("LOCAL_RANK", 0))

    if world_size < 2:
        log("  SKIP: Need at least 2 ranks for P2P test")
        return None

    size_mb = 128
    num_elements = (size_mb * 1024 * 1024) // 4
    tensor = torch.randn(num_elements, device=f"cuda:{local_rank}")

    # Only rank 0 and rank 1 participate
    # Use first GPU on each node (local_rank 0)
    if local_rank != 0:
        log("  SKIP: Only local_rank 0 on each node runs P2P test")
        dist.barrier()
        return None

    if rank > 1:
        dist.barrier()
        return None

    # Warmup
    for _ in range(5):
        if rank == 0:
            dist.send(tensor, dst=1)
        else:
            dist.recv(tensor, src=0)

    torch.cuda.synchronize()

    # Timed
    num_iters = 20
    torch.cuda.synchronize()
    start = time.perf_counter()

    for _ in range(num_iters):
        if rank == 0:
            dist.send(tensor, dst=1)
        else:
            dist.recv(tensor, src=0)

    torch.cuda.synchronize()
    elapsed = time.perf_counter() - start

    bw_gbps = (size_mb * num_iters * 8) / (elapsed * 1000)  # Gbps

    log(f"  {size_mb} MB x {num_iters} iters | Unidirectional BW: {bw_gbps:.2f} Gbps")
    log("  PASS: P2P bandwidth test complete")

    dist.barrier()
    return {"size_mb": size_mb, "bw_gbps": round(bw_gbps, 2)}


def main():
    rank_info = {
        "hostname": socket.gethostname(),
        "cuda_devices": torch.cuda.device_count(),
        "nccl_version": torch.cuda.nccl.version(),
    }

    print(f"\n{'#' * 60}")
    print(f"# EFA & NCCL BASELINE VALIDATION")
    print(f"# Host: {rank_info['hostname']}")
    print(f"# CUDA devices: {rank_info['cuda_devices']}")
    print(f"# NCCL version: {rank_info['nccl_version']}")
    print(f"# Timestamp: {datetime.utcnow().isoformat()}")
    print(f"{'#' * 60}\n")

    results = {"checks": {}, "passed": True}

    # Check 1: EFA devices
    efa_ok = check_efa_devices()
    results["checks"]["efa_devices"] = efa_ok

    # Check 2: NCCL init
    nccl_ok = check_nccl_init()
    results["checks"]["nccl_init"] = nccl_ok

    if not nccl_ok:
        log("\nFATAL: NCCL init failed, cannot continue with remaining checks")
        results["passed"] = False
        sys.exit(1)

    # Check 3: All-reduce correctness
    ar_ok = check_allreduce_correctness()
    results["checks"]["allreduce_correctness"] = ar_ok

    # Check 4: All-reduce bandwidth
    if dist.get_rank() == 0:
        bw_results = check_allreduce_bandwidth()
        results["allreduce_bandwidth"] = bw_results
    else:
        check_allreduce_bandwidth()

    # Check 5: P2P bandwidth
    p2p = check_p2p_bandwidth()
    if dist.get_rank() == 0 and p2p:
        results["p2p_bandwidth"] = p2p

    # Final summary
    if dist.get_rank() == 0:
        all_passed = all(results["checks"].values())
        results["passed"] = all_passed

        log("")
        log("=" * 60)
        log("VALIDATION SUMMARY")
        log("=" * 60)
        for check, status in results["checks"].items():
            icon = "✓" if status else "✗"
            log(f"  [{icon}] {check}")
        log("")
        log(f"  Overall: {'PASS' if all_passed else 'FAIL'}")
        log("=" * 60)

        with open("/workspace/results/validation.json", "w") as f:
            json.dump(results, f, indent=2)

    dist.destroy_process_group()

    if not results.get("passed", False) and dist.get_rank() == 0:
        sys.exit(1)


if __name__ == "__main__":
    main()

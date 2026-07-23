"""
Scenario Injection — Creates real failures in the cluster for benchmark testing.
Each injection method simulates the failure condition, waits for symptoms to manifest,
then captures the system state for both agents to analyze.
"""
import os
import sys
import json
import time
import argparse
import subprocess
from pathlib import Path
from datetime import datetime

from definitions import SCENARIOS

NAMESPACE = os.environ.get("APP_NAMESPACE", "aiops-app")
CLUSTER_NAME = os.environ.get("CLUSTER_NAME", "aiops-test-cluster")


def kubectl(args: str, capture: bool = True) -> str:
    """Execute kubectl command."""
    cmd = f"kubectl -n {NAMESPACE} {args}"
    result = subprocess.run(cmd.split(), capture_output=capture, text=True)
    if result.returncode != 0 and capture:
        print(f"kubectl error: {result.stderr}", file=sys.stderr)
    return result.stdout if capture else ""


def inject_oom_cascade():
    """Inject OOMKill scenario by running memory-intensive query in PostgreSQL."""
    print("Injecting OOM cascade scenario...")

    # Get postgres pod name
    pod = kubectl("get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}'").strip("'")

    # Run memory-intensive operation inside postgres
    # Allocate large array in a plpgsql function to exceed 512Mi
    sql = """
    DO $$ 
    DECLARE 
        big_array text[];
    BEGIN
        -- Allocate ~600MB of string data to exceed 512Mi limit
        FOR i IN 1..50000000 LOOP
            big_array := array_append(big_array, repeat('x', 100));
        END LOOP;
    END $$;
    """
    kubectl(f"exec {pod} -- psql -U aiops_user -d aiops -c \"{sql}\"", capture=False)
    print("  Memory pressure applied. Waiting for OOMKill...")
    time.sleep(30)  # Wait for OOMKill to trigger


def inject_cpu_throttle():
    """Inject CPU throttling by generating sustained load."""
    print("Injecting CPU throttle scenario...")

    # Get frontend service endpoint
    svc_ip = kubectl("get svc frontend -o jsonpath='{.spec.clusterIP}'").strip("'")

    # Run load test pod
    load_cmd = f"""run load-test --image=busybox --restart=Never --command -- \
        /bin/sh -c "for i in $(seq 1 100); do wget -q -O /dev/null http://{svc_ip}/login & done; wait"
    """
    kubectl(load_cmd)
    print("  Load test started. Waiting for CPU pressure to build...")
    time.sleep(120)


def inject_disk_pressure():
    """Inject disk pressure by filling PostgreSQL PVC."""
    print("Injecting disk pressure scenario...")

    pod = kubectl("get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}'").strip("'")

    # Create large temp file to fill the 5Gi PVC
    sql = """
    CREATE TABLE IF NOT EXISTS _fill_disk AS 
    SELECT generate_series(1, 10000000) as id, 
           repeat('x', 500) as padding;
    """
    kubectl(f"exec {pod} -- psql -U aiops_user -d aiops -c \"{sql}\"", capture=False)
    print("  Disk fill initiated. Waiting for ENOSPC...")
    time.sleep(60)


def inject_dns_failure():
    """Inject DNS failure by scaling CoreDNS down."""
    print("Injecting DNS failure scenario...")
    subprocess.run("kubectl -n kube-system scale deployment coredns --replicas=0".split())
    print("  CoreDNS scaled to 0. Waiting for DNS failures to propagate...")
    time.sleep(30)

    # Restore partially (degraded state)
    subprocess.run("kubectl -n kube-system scale deployment coredns --replicas=1".split())
    print("  CoreDNS restored to 1 replica (degraded).")
    time.sleep(15)


def inject_restart_loop():
    """Inject restart loop by patching readiness probe to wrong path."""
    print("Injecting restart loop scenario...")

    patch = json.dumps({
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "frontend",
                        "readinessProbe": {
                            "httpGet": {"path": "/healthz", "port": 5000},
                            "initialDelaySeconds": 5,
                            "periodSeconds": 3,
                            "failureThreshold": 3,
                        },
                    }],
                },
            },
        },
    })
    kubectl(f"patch deployment frontend --type=strategic -p '{patch}'")
    print("  Readiness probe patched to /healthz. Waiting for restart loop...")
    time.sleep(60)


def capture_state() -> dict:
    """Capture current cluster state for agent consumption."""
    state = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "cluster": CLUSTER_NAME,
        "namespace": NAMESPACE,
        "pods": json.loads(kubectl("get pods -o json") or "{}"),
        "events": json.loads(kubectl("get events --sort-by=.lastTimestamp -o json") or "{}"),
        "services": json.loads(kubectl("get svc -o json") or "{}"),
    }
    return state


INJECTORS = {
    "oom-cascade": inject_oom_cascade,
    "cpu-throttle": inject_cpu_throttle,
    "disk-pressure": inject_disk_pressure,
    "dns-failure": inject_dns_failure,
    "restart-loop": inject_restart_loop,
}


def main():
    parser = argparse.ArgumentParser(description="Inject failure scenarios for benchmarking")
    parser.add_argument("--scenario", "-s", required=True, choices=list(SCENARIOS.keys()))
    parser.add_argument("--capture-only", action="store_true", help="Only capture state, don't inject")
    parser.add_argument("--output", "-o", default="state.json", help="Output file for captured state")
    args = parser.parse_args()

    if not args.capture_only:
        injector = INJECTORS.get(args.scenario)
        if injector:
            injector()
            print(f"\nScenario '{args.scenario}' injected. Capturing state...")
        else:
            print(f"No injector for scenario: {args.scenario}")
            sys.exit(1)

    # Capture system state
    state = capture_state()
    state["scenario"] = args.scenario

    output_path = Path(args.output)
    output_path.write_text(json.dumps(state, indent=2, default=str))
    print(f"State captured to: {output_path}")


if __name__ == "__main__":
    main()

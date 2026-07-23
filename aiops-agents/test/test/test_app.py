"""
Validate application stack deployment and connectivity.
"""
import pytest
import time


class TestApplicationDeployment:
    """Validate all app components are deployed and healthy."""

    def test_namespace_exists(self, k8s_client, namespace):
        """Verify aiops-app namespace exists."""
        ns = k8s_client.read_namespace(name=namespace)
        assert ns.status.phase == "Active"

    def test_frontend_pods_running(self, k8s_client, namespace):
        """Verify frontend pods are running."""
        pods = k8s_client.list_namespaced_pod(
            namespace=namespace, label_selector="app=frontend"
        )
        running = [p for p in pods.items if p.status.phase == "Running"]
        assert len(running) >= 1, "No frontend pods running"

    def test_redis_pod_running(self, k8s_client, namespace):
        """Verify Redis pod is running."""
        pods = k8s_client.list_namespaced_pod(
            namespace=namespace, label_selector="app=redis"
        )
        running = [p for p in pods.items if p.status.phase == "Running"]
        assert len(running) == 1, "Redis not running"

    def test_postgres_pod_running(self, k8s_client, namespace):
        """Verify PostgreSQL pod is running."""
        pods = k8s_client.list_namespaced_pod(
            namespace=namespace, label_selector="app=postgres"
        )
        running = [p for p in pods.items if p.status.phase == "Running"]
        assert len(running) == 1, "PostgreSQL not running"

    def test_frontend_service_exists(self, k8s_client, namespace):
        """Verify frontend service is created with LoadBalancer."""
        svc = k8s_client.read_namespaced_service(name="frontend", namespace=namespace)
        assert svc.spec.type == "LoadBalancer"
        assert svc.spec.ports[0].port == 80

    def test_redis_service_exists(self, k8s_client, namespace):
        """Verify Redis service is created."""
        svc = k8s_client.read_namespaced_service(name="redis", namespace=namespace)
        assert svc.spec.type == "ClusterIP"
        assert svc.spec.ports[0].port == 6379

    def test_postgres_service_exists(self, k8s_client, namespace):
        """Verify PostgreSQL service is created."""
        svc = k8s_client.read_namespaced_service(name="postgres", namespace=namespace)
        assert svc.spec.type == "ClusterIP"
        assert svc.spec.ports[0].port == 5432


class TestDatabaseHydration:
    """Validate database has been seeded with test data."""

    def test_hydrate_job_completed(self, k8s_client, namespace):
        """Verify hydration job completed successfully."""
        # Use batch API for job status
        from kubernetes import client as k8s

        batch_v1 = k8s.BatchV1Api()
        job = batch_v1.read_namespaced_job(name="hydrate-db", namespace=namespace)
        assert job.status.succeeded >= 1, "Hydration job not completed"

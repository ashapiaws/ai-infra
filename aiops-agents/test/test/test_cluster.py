"""
Validate EKS cluster is healthy and properly configured.
"""
import pytest
from kubernetes import client


class TestClusterHealth:
    """Validate core cluster components."""

    def test_cluster_exists(self, eks_client, cluster_name):
        """Verify EKS cluster is active."""
        response = eks_client.describe_cluster(name=cluster_name)
        cluster = response["cluster"]
        assert cluster["status"] == "ACTIVE"
        assert cluster["name"] == cluster_name

    def test_cluster_version(self, eks_client, cluster_name):
        """Verify cluster is running expected Kubernetes version."""
        response = eks_client.describe_cluster(name=cluster_name)
        version = response["cluster"]["version"]
        assert version.startswith("1.3"), f"Expected 1.3x, got {version}"

    def test_nodes_ready(self, k8s_client):
        """Verify all nodes are in Ready state."""
        nodes = k8s_client.list_node()
        assert len(nodes.items) >= 1, "No nodes found"

        for node in nodes.items:
            conditions = {c.type: c.status for c in node.status.conditions}
            assert conditions.get("Ready") == "True", (
                f"Node {node.metadata.name} is not ready"
            )

    def test_system_pods_running(self, k8s_client):
        """Verify kube-system pods are running."""
        pods = k8s_client.list_namespaced_pod(namespace="kube-system")
        running_pods = [
            p for p in pods.items if p.status.phase in ("Running", "Succeeded")
        ]
        assert len(running_pods) > 0, "No running pods in kube-system"

    def test_coredns_running(self, k8s_client):
        """Verify CoreDNS is running."""
        pods = k8s_client.list_namespaced_pod(
            namespace="kube-system", label_selector="k8s-app=kube-dns"
        )
        running = [p for p in pods.items if p.status.phase == "Running"]
        assert len(running) >= 1, "CoreDNS not running"

    def test_ebs_csi_driver_running(self, k8s_client):
        """Verify EBS CSI driver pods are running."""
        pods = k8s_client.list_namespaced_pod(
            namespace="kube-system", label_selector="app=ebs-csi-controller"
        )
        running = [p for p in pods.items if p.status.phase == "Running"]
        assert len(running) >= 1, "EBS CSI controller not running"


class TestNetworking:
    """Validate cluster networking."""

    def test_vpc_cni_running(self, k8s_client):
        """Verify VPC CNI (aws-node) is running on all nodes."""
        pods = k8s_client.list_namespaced_pod(
            namespace="kube-system", label_selector="k8s-app=aws-node"
        )
        nodes = k8s_client.list_node()
        assert len(pods.items) >= len(nodes.items), "aws-node not on all nodes"

    def test_services_have_cluster_ips(self, k8s_client):
        """Verify Kubernetes services have ClusterIPs."""
        svc = k8s_client.read_namespaced_service(
            name="kubernetes", namespace="default"
        )
        assert svc.spec.cluster_ip is not None

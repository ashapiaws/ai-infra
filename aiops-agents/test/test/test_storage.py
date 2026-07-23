"""
Validate EBS CSI Driver and persistent storage.
"""
import pytest


class TestStorageClass:
    """Validate storage classes are configured."""

    def test_gp3_storage_class_exists(self, k8s_storage_client):
        """Verify gp3 StorageClass exists and is default."""
        scs = k8s_storage_client.list_storage_class()
        gp3 = None
        for sc in scs.items:
            if sc.metadata.name == "gp3":
                gp3 = sc
                break
        assert gp3 is not None, "gp3 StorageClass not found"
        assert gp3.provisioner == "ebs.csi.aws.com"
        annotations = gp3.metadata.annotations or {}
        assert annotations.get("storageclass.kubernetes.io/is-default-class") == "true"

    def test_gp3_encrypted(self, k8s_storage_client):
        """Verify gp3 StorageClass uses encrypted volumes."""
        scs = k8s_storage_client.list_storage_class()
        for sc in scs.items:
            if sc.metadata.name == "gp3":
                assert sc.parameters.get("encrypted") == "true"


class TestPersistentVolumes:
    """Validate PVCs are bound."""

    def test_postgres_pvc_bound(self, k8s_client, namespace):
        """Verify PostgreSQL PVC is bound to a volume."""
        pvc = k8s_client.read_namespaced_persistent_volume_claim(
            name="postgres-pvc", namespace=namespace
        )
        assert pvc.status.phase == "Bound", f"PVC status: {pvc.status.phase}"

    def test_postgres_pvc_size(self, k8s_client, namespace):
        """Verify PVC has correct storage request."""
        pvc = k8s_client.read_namespaced_persistent_volume_claim(
            name="postgres-pvc", namespace=namespace
        )
        storage = pvc.spec.resources.requests.get("storage")
        assert storage == "5Gi"

"""
Pytest configuration and shared fixtures for AIOps test validation.
"""
import os
import json
import pytest
import boto3
from kubernetes import client, config


@pytest.fixture(scope="session")
def cluster_name():
    """EKS cluster name from environment or default."""
    return os.environ.get("CLUSTER_NAME", "aiops-test-cluster")


@pytest.fixture(scope="session")
def region():
    """AWS region from environment or default."""
    return os.environ.get("AWS_REGION", "us-west-2")


@pytest.fixture(scope="session")
def namespace():
    """Application namespace."""
    return "aiops-app"


@pytest.fixture(scope="session")
def k8s_client():
    """Initialize Kubernetes client from kubeconfig."""
    try:
        config.load_kube_config()
    except config.ConfigException:
        config.load_incluster_config()
    return client.CoreV1Api()


@pytest.fixture(scope="session")
def k8s_apps_client():
    """Kubernetes apps/v1 client."""
    try:
        config.load_kube_config()
    except config.ConfigException:
        config.load_incluster_config()
    return client.AppsV1Api()


@pytest.fixture(scope="session")
def k8s_storage_client():
    """Kubernetes storage client."""
    try:
        config.load_kube_config()
    except config.ConfigException:
        config.load_incluster_config()
    return client.StorageV1Api()


@pytest.fixture(scope="session")
def eks_client(region):
    """AWS EKS client."""
    return boto3.client("eks", region_name=region)


@pytest.fixture(scope="session")
def cloudwatch_client(region):
    """AWS CloudWatch client."""
    return boto3.client("cloudwatch", region_name=region)


@pytest.fixture(scope="session")
def logs_client(region):
    """AWS CloudWatch Logs client."""
    return boto3.client("logs", region_name=region)


@pytest.fixture(scope="session")
def ec2_client(region):
    """AWS EC2 client."""
    return boto3.client("ec2", region_name=region)

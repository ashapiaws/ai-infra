# EKS Base Cluster

Terraform deployment for standing up an EKS cluster on an existing VPC with configurable node groups and infrastructure services.

## What This Creates

- EKS cluster with configurable Kubernetes version
- System node group (general workloads)
- GPU node group (optional, with taints for GPU scheduling)
- OIDC provider for IRSA
- CSI drivers (EBS, EFS, FSx for Lustre)
- Cilium CNI (optional, replaces VPC CNI)
- CloudWatch Container Insights (enabled by default)
- Prometheus + Grafana in-cluster (optional)

## Prerequisites

- Existing VPC with private subnets tagged `kubernetes.io/role/internal-elb = 1`
- AWS CLI configured
- Terraform >= 1.5.0

## Usage

```bash
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Inputs

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | Name of the EKS cluster | (required) |
| `vpc_id` | Existing VPC ID | (required) |
| `aws_region` | AWS region | `us-west-2` |
| `cluster_version` | Kubernetes version | `1.31` |
| `enable_gpu_nodes` | Create a GPU node group | `false` |
| `gpu_instance_types` | GPU instance types | `["g6.xlarge"]` |
| `enable_ebs_csi` | Deploy EBS CSI driver | `true` |
| `enable_efs_csi` | Deploy EFS CSI driver | `false` |
| `enable_fsx_csi` | Deploy FSx Lustre CSI driver | `false` |
| `enable_cilium` | Deploy Cilium CNI | `false` |
| `enable_cloudwatch` | CloudWatch Container Insights | `true` |
| `enable_prometheus_grafana` | In-cluster Prometheus + Grafana | `false` |

## Outputs

Cluster endpoint, CA cert, OIDC provider ARN, and security group ID are exported for use by downstream modules (e.g., `eks/systems/ai`).

## Connecting to the Systems Layer

After this cluster is up, deploy the AI systems layer:

```bash
cd ../../systems/ai
# dev.tfvars just needs cluster_name = "ai-dev-cluster" — endpoint is fetched dynamically
terraform init
terraform apply -var-file=dev.tfvars
```

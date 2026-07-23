# ML Infrastructure Platform - Terraform Configuration

This Terraform configuration provisions a complete ML infrastructure platform on AWS, including EKS cluster with GPU acceleration, S3 model registry, and comprehensive security controls.

## Architecture Overview

The infrastructure includes:
- **EKS Cluster**: Kubernetes cluster with dual node groups (CPU/GPU)
- **GPU Acceleration**: NVIDIA Operator, Device Plugin, EFA Plugin, DCGM
- **Model Registry**: S3 buckets with encryption and lifecycle policies
- **Security**: IAM roles with least-privilege access, KMS encryption
- **Observability**: CloudWatch logging and monitoring integration

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **kubectl** for cluster management
4. **Existing VPC** with subnets for EKS deployment

### Required AWS Permissions

The deploying user/role needs permissions for:
- EKS cluster and node group management
- S3 bucket creation and management
- IAM role and policy management
- KMS key management
- VPC and security group access

## Directory Structure

```
terraform/
├── main.tf                    # Main Terraform configuration
├── providers.tf               # Provider configurations
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── irsa-roles.tf             # IRSA roles for workloads
├── backend.tf                # Backend configuration template
├── modules/
│   ├── eks/                  # EKS cluster module
│   ├── s3/                   # S3 model registry module
│   └── iam/                  # IAM roles and policies module
├── environments/
│   ├── dev.tfvars           # Development environment variables
│   └── prod.tfvars          # Production environment variables
└── backend-configs/
    ├── backend-dev.hcl      # Development backend config
    └── backend-prod.hcl     # Production backend config
```

## Deployment Instructions

### Step 1: Prepare Backend Infrastructure

Before deploying the main infrastructure, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for state (replace with your bucket name)
aws s3 mb s3://ml-platform-terraform-state-dev --region us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ml-platform-terraform-state-dev \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name ml-platform-terraform-locks-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-west-2
```

### Step 2: Configure Environment Variables

1. **Update VPC Configuration**: Edit `environments/dev.tfvars` or `environments/prod.tfvars` with your actual VPC ID and subnet configuration:

**Option 1: Tag-based Subnet Selection (Recommended)**
```hcl
vpc_id = "vpc-your-actual-vpc-id"

# Automatically select private subnets based on tags
subnet_tag_filters = [
  {
    name   = "Name"
    values = ["*private*", "*priv*"]
  },
  {
    name   = "Type"
    values = ["private"]
  }
]
```

**Option 2: Explicit Subnet IDs**
```hcl
vpc_id = "vpc-your-actual-vpc-id"
subnet_ids = [
  "subnet-your-actual-private-subnet-1",
  "subnet-your-actual-private-subnet-2",
  "subnet-your-actual-private-subnet-3"
]
```

**Important Security Note**: The configuration defaults to selecting private subnets for enhanced security. EKS clusters should be deployed in private subnets to prevent direct internet access to worker nodes.

2. **Update Backend Configuration**: Edit `backend-configs/backend-dev.hcl` with your actual S3 bucket name:

```hcl
bucket = "your-actual-terraform-state-bucket"
```

### Step 3: Deploy Infrastructure

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform with backend configuration
terraform init -backend-config=backend-configs/backend-dev.hcl

# Review the deployment plan
terraform plan -var-file=environments/dev.tfvars

# Deploy the infrastructure
terraform apply -var-file=environments/dev.tfvars
```

### Step 4: Configure kubectl

After successful deployment, configure kubectl to access the EKS cluster:

```bash
# Update kubeconfig (replace with your cluster name and region)
aws eks update-kubeconfig --region us-west-2 --name ml-platform-dev

# Verify cluster access
kubectl get nodes
```

## Subnet Selection and Security

### Private Subnet Requirements

For security best practices, the EKS cluster should be deployed in private subnets. The configuration supports two methods for subnet selection:

1. **Tag-based Selection (Recommended)**: Automatically selects subnets based on tags
2. **Explicit Subnet IDs**: Manually specify subnet IDs

### Subnet Tagging Best Practices

Ensure your private subnets are tagged appropriately:

```bash
# Example subnet tags for private subnets
Name: "ml-platform-private-subnet-1a"
Type: "private"
Environment: "dev" or "prod"
kubernetes.io/role/internal-elb: "1"
```

### Tag Filter Examples

```hcl
# Select subnets with "private" in the name
subnet_tag_filters = [
  {
    name   = "Name"
    values = ["*private*"]
  }
]

# Select subnets by type and environment
subnet_tag_filters = [
  {
    name   = "Type"
    values = ["private"]
  },
  {
    name   = "Environment"
    values = ["prod"]
  }
]
```

### Validation

The configuration automatically validates that:
- At least 2 subnets are selected for high availability
- All selected subnets exist in the specified VPC
- Subnets are distributed across multiple availability zones (recommended)

### Node Group Configuration

The configuration supports separate CPU and GPU node groups:

- **CPU Nodes**: Autoscaling enabled for cost optimization
- **GPU Nodes**: Fixed sizing for cost control and predictability

### Security Features

- **Encryption**: All data encrypted at rest (S3, EBS) and in transit (TLS)
- **IAM Roles**: Least-privilege access with IRSA for workloads
- **Network Security**: Security groups and network policies
- **Audit Logging**: Comprehensive logging for compliance

### Observability

- **EKS Logging**: Control plane logs to CloudWatch
- **GPU Monitoring**: DCGM exporter for GPU metrics
- **S3 Access Logs**: Audit trail for model registry access

## Customization

### Adding New Environments

1. Create new variable file: `environments/staging.tfvars`
2. Create new backend config: `backend-configs/backend-staging.hcl`
3. Deploy with: `terraform apply -var-file=environments/staging.tfvars`

### Modifying Node Groups

Update the `cluster_config` in your environment's `.tfvars` file:

```hcl
cluster_config = {
  node_groups = {
    cpu_nodes = {
      instance_types = ["m5.2xlarge"]  # Larger instances
      max_size      = 20               # Higher scaling limit
    }
    gpu_nodes = {
      instance_types = ["p3.8xlarge"]  # More powerful GPUs
      desired_size   = 8               # More GPU nodes
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **VPC/Subnet Not Found**: Verify VPC ID and subnet IDs in your `.tfvars` file
2. **Permission Denied**: Ensure AWS credentials have required permissions
3. **State Lock**: If deployment fails, unlock state: `terraform force-unlock <lock-id>`

### Validation Commands

```bash
# Validate Terraform configuration
terraform validate

# Check formatting
terraform fmt -check

# Verify EKS cluster
kubectl get nodes -o wide

# Check GPU nodes
kubectl get nodes -l node-type=gpu

# Verify S3 buckets
aws s3 ls | grep ml-platform
```

## Cleanup

To destroy the infrastructure:

```bash
# Destroy infrastructure (be careful!)
terraform destroy -var-file=environments/dev.tfvars

# Clean up backend resources (manual)
aws s3 rb s3://ml-platform-terraform-state-dev --force
aws dynamodb delete-table --table-name ml-platform-terraform-locks-dev
```

## Security Considerations

1. **State File Security**: Terraform state contains sensitive information. Ensure S3 bucket has proper access controls.
2. **KMS Keys**: The configuration creates customer-managed KMS keys. Manage key policies carefully.
3. **Network Access**: Review security group rules and VPC configuration for your security requirements.
4. **IAM Permissions**: Regularly audit IAM roles and policies for least-privilege compliance.

## Next Steps

After infrastructure deployment:

1. **Deploy NVIDIA Operator**: Use Helm to install GPU acceleration components
2. **Set up Observability**: Deploy Prometheus and Grafana for monitoring
3. **Configure Ray**: Deploy Ray cluster for distributed training
4. **Deploy vLLM**: Set up inference services for model serving

See the main project documentation for application deployment instructions.
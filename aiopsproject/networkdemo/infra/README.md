# EKS Terraform Infrastructure

This directory contains Terraform configuration for provisioning an Amazon EKS (Elastic Kubernetes Service) cluster within an existing VPC. The infrastructure uses official AWS Terraform modules and follows AWS best practices for security, observability, and maintainability.

## Project Structure

```
infra/
├── backend.tf                  # Remote state backend configuration (commented out by default)
├── main.tf                     # Main Terraform configuration (EKS cluster, IAM, add-ons)
├── outputs.tf                  # Output definitions for cluster information
├── variables.tf                # Input variable definitions with validation
├── versions.tf                 # Terraform and provider version constraints
├── terraform.tfvars.example    # Example variable values (copy to terraform.tfvars)
└── README.md                   # This file
```

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **Terraform** >= 1.5 installed ([Download](https://www.terraform.io/downloads))
2. **AWS CLI** configured with appropriate credentials
3. **Existing VPC** with at least 2 private subnets across different availability zones
4. **IAM Permissions** to create EKS clusters, IAM roles, and related resources
5. **NAT Gateway** configured in your VPC for outbound internet access from private subnets

## Quick Start

### 1. Configure Variables

Copy the example tfvars file and customize it with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and provide:
- Your cluster name
- AWS region
- Existing VPC ID
- Private subnet IDs (at least 2)
- Node group configuration
- Any other customizations

### 2. Initialize Terraform

Initialize the Terraform working directory:

```bash
terraform init
```

### 3. Review the Plan

Preview the resources that will be created:

```bash
terraform plan
```

Review the output carefully to ensure the configuration matches your expectations.

### 4. Apply the Configuration

Create the infrastructure:

```bash
terraform apply
```

Type `yes` when prompted to confirm. The EKS cluster creation typically takes 15-20 minutes.

### 5. Configure kubectl

Once the cluster is created, configure kubectl to access it:

```bash
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>
```

Verify connectivity:

```bash
kubectl get nodes
```

## Configuration Options

### Required Variables

- `cluster_name`: Name of your EKS cluster
- `kubernetes_version`: Kubernetes version (e.g., "1.28")
- `region`: AWS region for deployment
- `vpc_id`: ID of your existing VPC
- `private_subnet_ids`: List of private subnet IDs

### Optional Variables

See `variables.tf` for a complete list of configurable options, including:
- Node group sizing (min, max, desired)
- Instance types
- Capacity type (ON_DEMAND or SPOT)
- KMS encryption key
- Add-on versions
- Additional IAM policies
- Resource tags

## Remote State Backend

For team collaboration, configure remote state storage in S3:

1. Create an S3 bucket with versioning enabled
2. Create a DynamoDB table with primary key "LockID" (String type)
3. Uncomment and configure the backend block in `backend.tf`
4. Run `terraform init` to migrate state

## Installed Components

This configuration provisions:

### Core Infrastructure
- EKS cluster with configurable Kubernetes version
- Managed node group with auto-scaling
- IAM roles for cluster and nodes
- Security groups with least-privilege rules

### Essential Add-ons
- **VPC CNI**: Pod networking
- **CoreDNS**: Service discovery
- **kube-proxy**: Network proxying
- **EBS CSI Driver**: Persistent storage

### Observability
- **CloudWatch Observability**: Container Insights and logging
- **ADOT**: AWS Distro for OpenTelemetry

### Load Balancing
- **AWS Load Balancer Controller**: ALB/NLB integration

## Security Features

- Private API endpoint access by default
- Cluster encryption with KMS (optional)
- IMDSv2 enforcement on nodes
- Comprehensive cluster logging (audit, API, authenticator, controller manager, scheduler)
- IAM Roles for Service Accounts (IRSA) for add-ons

## Outputs

After successful deployment, Terraform outputs include:
- Cluster endpoint and name
- Security group IDs
- IAM role ARNs
- OIDC provider information
- Add-on versions

View outputs:

```bash
terraform output
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete your EKS cluster and all associated resources. Ensure you have backed up any important data.

## Troubleshooting

### Common Issues

**Issue**: Terraform validation fails
- **Solution**: Ensure all required variables are set in `terraform.tfvars`

**Issue**: Insufficient IAM permissions
- **Solution**: Verify your AWS credentials have permissions to create EKS clusters, IAM roles, and EC2 resources

**Issue**: Subnets not in VPC
- **Solution**: Verify that all subnet IDs in `private_subnet_ids` belong to the specified VPC

**Issue**: Node count validation error
- **Solution**: Ensure `node_group_min_size <= node_group_desired_size <= node_group_max_size`

**Issue**: Cluster creation timeout
- **Solution**: EKS cluster creation can take 15-20 minutes. If it times out, check AWS Console for error details

## Next Steps

After deploying the cluster:

1. **Configure kubectl**: Update your kubeconfig to access the cluster
2. **Deploy applications**: Use kubectl or Helm to deploy your workloads
3. **Configure monitoring**: Review CloudWatch Container Insights dashboards
4. **Set up CI/CD**: Integrate with your deployment pipelines
5. **Configure autoscaling**: Set up Cluster Autoscaler or Karpenter for node scaling

## Support and Documentation

- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Terraform Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

## License

This configuration is provided as-is for use in your AWS environment.

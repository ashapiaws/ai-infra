#!/bin/bash

# EKS Observability Stack Validation Script
# Validates the Terraform configuration and checks prerequisites

set -e

echo "🔍 EKS Observability Stack Validation"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
    esac
}

# Check prerequisites
echo "Checking prerequisites..."

# Check Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    print_status "OK" "Terraform installed: $TERRAFORM_VERSION"
else
    print_status "ERROR" "Terraform not found. Please install Terraform >= 1.0"
    exit 1
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version | cut -d/ -f2 | cut -d' ' -f1)
    print_status "OK" "AWS CLI installed: $AWS_VERSION"
else
    print_status "ERROR" "AWS CLI not found. Please install AWS CLI"
    exit 1
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)
    print_status "OK" "kubectl installed: $KUBECTL_VERSION"
else
    print_status "WARN" "kubectl not found. Install kubectl to manage the cluster"
fi

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text | cut -d'/' -f2)
    print_status "OK" "AWS credentials configured: $AWS_USER (Account: $AWS_ACCOUNT)"
else
    print_status "ERROR" "AWS credentials not configured. Run 'aws configure'"
    exit 1
fi

echo ""
echo "Validating Terraform configuration..."

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    print_status "WARN" "Terraform not initialized. Running 'terraform init'..."
    terraform init
fi

# Validate Terraform configuration
if terraform validate; then
    print_status "OK" "Terraform configuration is valid"
else
    print_status "ERROR" "Terraform configuration validation failed"
    exit 1
fi

# Check formatting
if terraform fmt -check=true -diff=false; then
    print_status "OK" "Terraform files are properly formatted"
else
    print_status "WARN" "Terraform files need formatting. Run 'terraform fmt'"
fi

# Check for required variables file
if [ -f "terraform.tfvars" ]; then
    print_status "OK" "terraform.tfvars file found"
elif [ -f "environments/dev.tfvars" ]; then
    print_status "OK" "Development environment file found"
elif [ -f "environments/prod.tfvars" ]; then
    print_status "OK" "Production environment file found"
else
    print_status "WARN" "No terraform.tfvars file found. Copy from examples/ directory"
fi

echo ""
echo "Optional tools check..."

# Check optional tools
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short | cut -d' ' -f1)
    print_status "OK" "Helm installed: $HELM_VERSION"
else
    print_status "WARN" "Helm not found (managed by Terraform provider)"
fi

if command -v tflint &> /dev/null; then
    print_status "OK" "tflint available for linting"
else
    print_status "WARN" "tflint not found. Install with: brew install tflint"
fi

if command -v tfsec &> /dev/null; then
    print_status "OK" "tfsec available for security scanning"
else
    print_status "WARN" "tfsec not found. Install with: brew install tfsec"
fi

echo ""
echo "🎉 Validation complete!"
echo ""
echo "Next steps:"
echo "1. Copy and customize terraform.tfvars from examples/"
echo "2. Run 'terraform plan' to review changes"
echo "3. Run 'terraform apply' to deploy infrastructure"
echo "4. Run 'make kubeconfig' to configure kubectl"
echo "5. Run 'make grafana' to access monitoring dashboard"
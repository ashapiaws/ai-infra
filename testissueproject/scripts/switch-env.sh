#!/bin/bash

# Environment Switcher Script
# Helps switch between different environment configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
        "SUCCESS")
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

# Function to show usage
show_usage() {
    echo "Usage: $0 <environment>"
    echo ""
    echo "Available environments:"
    echo "  dev      - Development environment (cost-optimized)"
    echo "  staging  - Staging environment (production-like)"
    echo "  prod     - Production environment (high-availability)"
    echo ""
    echo "Examples:"
    echo "  $0 dev      # Switch to development"
    echo "  $0 staging  # Switch to staging"
    echo "  $0 prod     # Switch to production"
}

# Check if environment argument is provided
if [ $# -eq 0 ]; then
    print_status "ERROR" "No environment specified"
    show_usage
    exit 1
fi

ENVIRONMENT=$1
ENV_FILE="environments/${ENVIRONMENT}.tfvars"

# Validate environment
if [ ! -f "$ENV_FILE" ]; then
    print_status "ERROR" "Environment file not found: $ENV_FILE"
    echo ""
    echo "Available environments:"
    ls -1 environments/*.tfvars 2>/dev/null | sed 's/environments\///g' | sed 's/\.tfvars//g' | sed 's/^/  /'
    exit 1
fi

print_status "INFO" "Switching to $ENVIRONMENT environment"

# Create or update terraform.tfvars symlink
if [ -L "terraform.tfvars" ] || [ -f "terraform.tfvars" ]; then
    rm -f terraform.tfvars
fi

ln -s "$ENV_FILE" terraform.tfvars
print_status "SUCCESS" "Created symlink: terraform.tfvars -> $ENV_FILE"

# Show environment summary
print_status "INFO" "Environment Summary:"
echo ""

# Extract key information from the tfvars file
CLUSTER_NAME=$(grep '^cluster_name' "$ENV_FILE" | cut -d'"' -f2 2>/dev/null || echo "Not specified")
AWS_REGION=$(grep '^aws_region' "$ENV_FILE" | cut -d'"' -f2 2>/dev/null || echo "Not specified")
VPC_ID=$(grep '^vpc_id' "$ENV_FILE" | cut -d'"' -f2 2>/dev/null || echo "Not specified")

echo "  Cluster Name: $CLUSTER_NAME"
echo "  AWS Region:   $AWS_REGION"
echo "  VPC ID:       $VPC_ID"
echo ""

# Show next steps
print_status "INFO" "Next steps:"
echo "  1. Review configuration: cat terraform.tfvars"
echo "  2. Plan deployment:      terraform plan"
echo "  3. Apply changes:        terraform apply"
echo ""
echo "Or use make commands:"
echo "  make plan-$ENVIRONMENT"
echo "  make $ENVIRONMENT"

# Warning for production
if [ "$ENVIRONMENT" = "prod" ]; then
    echo ""
    print_status "WARN" "You are switching to PRODUCTION environment!"
    print_status "WARN" "Please review all changes carefully before applying."
fi
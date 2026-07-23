#!/bin/bash

# Environment Comparison Script
# Shows differences between environment configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "$(printf '=%.0s' $(seq 1 ${#1}))"
}

print_section() {
    echo -e "${GREEN}$1${NC}"
}

# Function to extract value from tfvars file
extract_value() {
    local file=$1
    local key=$2
    grep "^$key" "$file" 2>/dev/null | head -1 | cut -d'=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"'
}

# Function to extract complex values
extract_complex() {
    local file=$1
    local pattern=$2
    grep -A 5 "$pattern" "$file" 2>/dev/null | head -6
}

# Check if environment files exist
ENVS=("dev" "staging" "prod")
for env in "${ENVS[@]}"; do
    if [ ! -f "environments/${env}.tfvars" ]; then
        echo "Error: environments/${env}.tfvars not found"
        exit 1
    fi
done

print_header "EKS Observability Stack - Environment Comparison"
echo ""

# Basic Configuration Comparison
print_section "Basic Configuration"
printf "%-15s %-20s %-20s %-20s\n" "Setting" "Development" "Staging" "Production"
printf "%-15s %-20s %-20s %-20s\n" "-------" "-----------" "-------" "----------"

# Extract and compare basic settings
SETTINGS=(
    "cluster_name"
    "aws_region"
    "kubernetes_version"
    "subnet_type"
)

for setting in "${SETTINGS[@]}"; do
    dev_val=$(extract_value "environments/dev.tfvars" "$setting")
    staging_val=$(extract_value "environments/staging.tfvars" "$setting")
    prod_val=$(extract_value "environments/prod.tfvars" "$setting")
    printf "%-15s %-20s %-20s %-20s\n" "$setting" "$dev_val" "$staging_val" "$prod_val"
done

echo ""

# Node Groups Comparison
print_section "Node Groups Configuration"
echo ""

for env in "${ENVS[@]}"; do
    echo "=== $env Environment ==="
    
    # Primary node group
    echo "Primary Node Group:"
    instance_types=$(grep -A 10 "primary = {" "environments/${env}.tfvars" | grep "instance_types" | cut -d'[' -f2 | cut -d']' -f1 | tr -d '"')
    capacity_type=$(grep -A 10 "primary = {" "environments/${env}.tfvars" | grep "capacity_type" | cut -d'"' -f2)
    min_size=$(grep -A 15 "primary = {" "environments/${env}.tfvars" | grep "min_size" | grep -o '[0-9]*')
    max_size=$(grep -A 15 "primary = {" "environments/${env}.tfvars" | grep "max_size" | grep -o '[0-9]*')
    desired_size=$(grep -A 15 "primary = {" "environments/${env}.tfvars" | grep "desired_size" | grep -o '[0-9]*')
    
    echo "  Instance Types: $instance_types"
    echo "  Capacity Type:  $capacity_type"
    echo "  Scaling:        $min_size-$desired_size-$max_size (min-desired-max)"
    
    echo ""
done

# Observability Comparison
print_section "Observability Configuration"
echo ""

printf "%-15s %-15s %-15s %-15s\n" "Component" "Development" "Staging" "Production"
printf "%-15s %-15s %-15s %-15s\n" "---------" "-----------" "-------" "----------"

# Prometheus retention
for component in "prometheus" "grafana" "alertmanager"; do
    case $component in
        "prometheus")
            dev_val=$(grep -A 20 "prometheus = {" "environments/dev.tfvars" | grep "retention_days" | grep -o '[0-9]*')
            staging_val=$(grep -A 20 "prometheus = {" "environments/staging.tfvars" | grep "retention_days" | grep -o '[0-9]*')
            prod_val=$(grep -A 20 "prometheus = {" "environments/prod.tfvars" | grep "retention_days" | grep -o '[0-9]*')
            printf "%-15s %-15s %-15s %-15s\n" "Prom Retention" "${dev_val}d" "${staging_val}d" "${prod_val}d"
            ;;
        "grafana")
            dev_val=$(grep -A 30 "grafana = {" "environments/dev.tfvars" | grep "storage_size" | head -1 | cut -d'"' -f2)
            staging_val=$(grep -A 30 "grafana = {" "environments/staging.tfvars" | grep "storage_size" | head -1 | cut -d'"' -f2)
            prod_val=$(grep -A 30 "grafana = {" "environments/prod.tfvars" | grep "storage_size" | head -1 | cut -d'"' -f2)
            printf "%-15s %-15s %-15s %-15s\n" "Grafana Storage" "$dev_val" "$staging_val" "$prod_val"
            ;;
        "alertmanager")
            dev_val=$(grep -A 10 "alertmanager = {" "environments/dev.tfvars" | grep "enabled" | grep -o 'true\|false')
            staging_val=$(grep -A 10 "alertmanager = {" "environments/staging.tfvars" | grep "enabled" | grep -o 'true\|false')
            prod_val=$(grep -A 10 "alertmanager = {" "environments/prod.tfvars" | grep "enabled" | grep -o 'true\|false')
            printf "%-15s %-15s %-15s %-15s\n" "AlertManager" "$dev_val" "$staging_val" "$prod_val"
            ;;
    esac
done

echo ""

# Security Comparison
print_section "Security Configuration"
echo ""

printf "%-20s %-15s %-15s %-15s\n" "Security Feature" "Development" "Staging" "Production"
printf "%-20s %-15s %-15s %-15s\n" "----------------" "-----------" "-------" "----------"

# Extract security settings
for setting in "enable_remote_access" "enable_irsa"; do
    dev_val=$(extract_value "environments/dev.tfvars" "$setting")
    staging_val=$(extract_value "environments/staging.tfvars" "$setting")
    prod_val=$(extract_value "environments/prod.tfvars" "$setting")
    printf "%-20s %-15s %-15s %-15s\n" "$setting" "$dev_val" "$staging_val" "$prod_val"
done

# Endpoint access
dev_public=$(grep -A 5 "endpoint_config" "environments/dev.tfvars" | grep "public_access" | grep -o 'true\|false')
staging_public=$(grep -A 5 "endpoint_config" "environments/staging.tfvars" | grep "public_access" | grep -o 'true\|false')
prod_public=$(grep -A 5 "endpoint_config" "environments/prod.tfvars" | grep "public_access" | grep -o 'true\|false')
printf "%-20s %-15s %-15s %-15s\n" "public_access" "$dev_public" "$staging_public" "$prod_public"

echo ""

# Cost Optimization
print_section "Cost Optimization"
echo ""

echo "Development:"
echo "  - Spot instances for cost savings"
echo "  - Smaller instance types (t3.small)"
echo "  - Reduced logging retention (3-7 days)"
echo "  - Minimal monitoring resources"
echo "  - Auto-shutdown tags enabled"
echo ""

echo "Staging:"
echo "  - Mix of on-demand and spot instances"
echo "  - Medium instance types (t3.medium)"
echo "  - Moderate retention (15 days)"
echo "  - Production-like monitoring"
echo ""

echo "Production:"
echo "  - On-demand instances for stability"
echo "  - Large instance types (m5.large+)"
echo "  - Long retention (90 days)"
echo "  - High-resource monitoring"
echo "  - Performance optimizations enabled"
echo ""

print_section "Usage Examples"
echo ""
echo "Switch environments:"
echo "  ./scripts/switch-env.sh dev"
echo "  ./scripts/switch-env.sh staging"
echo "  ./scripts/switch-env.sh prod"
echo ""
echo "Deploy specific environment:"
echo "  make dev      # Deploy development"
echo "  make staging  # Deploy staging"
echo "  make prod     # Deploy production"
echo ""
echo "Plan specific environment:"
echo "  make plan-dev      # Plan development"
echo "  make plan-staging  # Plan staging"
echo "  make plan-prod     # Plan production"
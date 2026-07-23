# ML Infrastructure Platform - Terraform Makefile
# Provides convenient commands for managing Terraform deployments

.PHONY: help init plan apply destroy validate fmt check clean

# Default environment
ENV ?= dev

# Help target
help:
	@echo "ML Infrastructure Platform - Terraform Commands"
	@echo ""
	@echo "Usage: make <target> [ENV=<environment>]"
	@echo ""
	@echo "Targets:"
	@echo "  init      Initialize Terraform with backend configuration"
	@echo "  plan      Show deployment plan"
	@echo "  apply     Deploy infrastructure"
	@echo "  destroy   Destroy infrastructure (use with caution)"
	@echo "  validate  Validate Terraform configuration"
	@echo "  fmt       Format Terraform files"
	@echo "  check     Run validation and formatting checks"
	@echo "  clean     Clean Terraform cache and state"
	@echo ""
	@echo "Environments:"
	@echo "  dev       Development environment (default)"
	@echo "  prod      Production environment"
	@echo ""
	@echo "Examples:"
	@echo "  make init ENV=dev"
	@echo "  make plan ENV=prod"
	@echo "  make apply ENV=dev"

# Initialize Terraform
init:
	@echo "Initializing Terraform for $(ENV) environment..."
	terraform init -backend-config=backend-configs/backend-$(ENV).hcl

# Show deployment plan
plan:
	@echo "Creating deployment plan for $(ENV) environment..."
	terraform plan -var-file=environments/$(ENV).tfvars

# Deploy infrastructure
apply:
	@echo "Deploying infrastructure for $(ENV) environment..."
	terraform apply -var-file=environments/$(ENV).tfvars

# Destroy infrastructure
destroy:
	@echo "WARNING: This will destroy all infrastructure for $(ENV) environment!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read
	terraform destroy -var-file=environments/$(ENV).tfvars

# Validate configuration
validate:
	@echo "Validating Terraform configuration..."
	terraform validate

# Format Terraform files
fmt:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive

# Run all checks
check: validate fmt
	@echo "Running configuration checks..."
	terraform fmt -check -recursive

# Clean Terraform cache
clean:
	@echo "Cleaning Terraform cache..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate.backup

# Quick deployment for development
dev-deploy: init plan
	@echo "Quick deployment to development environment..."
	terraform apply -var-file=environments/dev.tfvars -auto-approve

# Production deployment with confirmation
prod-deploy: init plan
	@echo "Production deployment requires manual confirmation..."
	terraform apply -var-file=environments/prod.tfvars

# Update kubeconfig after deployment
kubeconfig:
	@echo "Updating kubeconfig for $(ENV) environment..."
	@CLUSTER_NAME=$$(terraform output -raw cluster_name 2>/dev/null || echo "ml-platform-$(ENV)"); \
	REGION=$$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2"); \
	aws eks update-kubeconfig --region $$REGION --name $$CLUSTER_NAME

# Show outputs
outputs:
	@echo "Terraform outputs for $(ENV) environment:"
	terraform output

# Refresh state
refresh:
	@echo "Refreshing Terraform state for $(ENV) environment..."
	terraform refresh -var-file=environments/$(ENV).tfvars

# Import existing resources (example)
import-vpc:
	@echo "Example: Import existing VPC (update VPC_ID variable)"
	@echo "terraform import aws_vpc.existing $(VPC_ID)"

# Backup state
backup-state:
	@echo "Backing up Terraform state..."
	@mkdir -p backups
	@cp terraform.tfstate backups/terraform.tfstate.$(shell date +%Y%m%d_%H%M%S)

# Show resource graph
graph:
	@echo "Generating resource dependency graph..."
	terraform graph | dot -Tpng > terraform-graph.png
	@echo "Graph saved as terraform-graph.png"
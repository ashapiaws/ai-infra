# EKS Observability Stack Makefile
# Provides convenient commands for managing the infrastructure

.PHONY: help init plan apply destroy validate fmt lint clean dev prod

# Default target
help: ## Show this help message
	@echo "EKS Observability Stack Management"
	@echo "=================================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Environment variables
ENV ?= dev
REGION ?= us-west-2
VAR_FILE = environments/$(ENV).tfvars

# Terraform commands
init: ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform validate
	terraform fmt -check=true -diff=true

fmt: ## Format Terraform files
	terraform fmt -recursive

plan: ## Plan Terraform changes
	@if [ -f "$(VAR_FILE)" ]; then \
		terraform plan -var-file="$(VAR_FILE)"; \
	else \
		echo "Variable file $(VAR_FILE) not found. Using default variables."; \
		terraform plan; \
	fi

apply: ## Apply Terraform changes
	@if [ -f "$(VAR_FILE)" ]; then \
		terraform apply -var-file="$(VAR_FILE)"; \
	else \
		echo "Variable file $(VAR_FILE) not found. Using default variables."; \
		terraform apply; \
	fi

destroy: ## Destroy infrastructure
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	@if [ -f "$(VAR_FILE)" ]; then \
		terraform destroy -var-file="$(VAR_FILE)"; \
	else \
		terraform destroy; \
	fi

# Environment-specific commands
dev: ## Deploy development environment
	$(MAKE) apply ENV=dev

staging: ## Deploy staging environment
	$(MAKE) apply ENV=staging

prod: ## Deploy production environment
	$(MAKE) apply ENV=prod

# Environment-specific planning
plan-dev: ## Plan development environment
	$(MAKE) plan ENV=dev

plan-staging: ## Plan staging environment
	$(MAKE) plan ENV=staging

plan-prod: ## Plan production environment
	$(MAKE) plan ENV=prod

# Utility commands
output: ## Show Terraform outputs
	terraform output

state: ## Show Terraform state
	terraform state list

refresh: ## Refresh Terraform state
	terraform refresh

# Kubernetes commands
kubeconfig: ## Update kubeconfig for the cluster
	@CLUSTER_NAME=$$(terraform output -raw cluster_id 2>/dev/null || echo ""); \
	if [ -n "$$CLUSTER_NAME" ]; then \
		aws eks update-kubeconfig --region $(REGION) --name $$CLUSTER_NAME; \
		echo "Kubeconfig updated for cluster: $$CLUSTER_NAME"; \
	else \
		echo "Cluster not found. Make sure infrastructure is deployed."; \
	fi

status: ## Show cluster and monitoring status
	@echo "=== Cluster Status ==="
	kubectl get nodes 2>/dev/null || echo "Cluster not accessible"
	@echo ""
	@echo "=== Monitoring Pods ==="
	kubectl get pods -n monitoring 2>/dev/null || echo "Monitoring namespace not found"

grafana: ## Port-forward to Grafana
	@echo "Starting port-forward to Grafana..."
	@echo "Access Grafana at: http://localhost:3000"
	@echo "Default credentials: admin / $$(terraform output -raw grafana_admin_password 2>/dev/null || echo 'check terraform output')"
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

prometheus: ## Port-forward to Prometheus
	@echo "Starting port-forward to Prometheus..."
	@echo "Access Prometheus at: http://localhost:9090"
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

alertmanager: ## Port-forward to AlertManager
	@echo "Starting port-forward to AlertManager..."
	@echo "Access AlertManager at: http://localhost:9093"
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Setup commands
setup-dev: ## Setup development environment
	@echo "Setting up development environment..."
	@mkdir -p environments
	@if [ ! -f "environments/dev.tfvars" ]; then \
		cp examples/dev/terraform.tfvars.example environments/dev.tfvars; \
		echo "Created environments/dev.tfvars - please edit with your configuration"; \
	else \
		echo "environments/dev.tfvars already exists"; \
	fi

setup-prod: ## Setup production environment
	@echo "Setting up production environment..."
	@mkdir -p environments
	@if [ ! -f "environments/prod.tfvars" ]; then \
		cp examples/basic/terraform.tfvars.example environments/prod.tfvars; \
		echo "Created environments/prod.tfvars - please edit with your configuration"; \
	else \
		echo "environments/prod.tfvars already exists"; \
	fi

# Cleanup commands
clean: ## Clean Terraform files
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f *.tfplan

# Linting and security
lint: ## Run tflint on Terraform files
	@if command -v tflint >/dev/null 2>&1; then \
		tflint; \
	else \
		echo "tflint not installed. Install with: brew install tflint"; \
	fi

security: ## Run security scan with tfsec
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec .; \
	else \
		echo "tfsec not installed. Install with: brew install tfsec"; \
	fi

# Documentation
docs: ## Generate documentation
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown table --output-file README.md .; \
	else \
		echo "terraform-docs not installed. Install with: brew install terraform-docs"; \
	fi

# Cost estimation
cost: ## Estimate costs with infracost
	@if command -v infracost >/dev/null 2>&1; then \
		infracost breakdown --path .; \
	else \
		echo "infracost not installed. See: https://www.infracost.io/docs/"; \
	fi
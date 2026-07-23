# EKS Quick Cluster - Makefile
# Usage: make apply ENV=dev | make destroy ENV=dev

ENV ?= dev
TFVARS = $(ENV).tfvars
PARALLELISM ?= 20
CLUSTER_NAME := $(shell grep 'cluster_name' $(TFVARS) 2>/dev/null | head -1 | sed 's/.*= *"\(.*\)"/\1/')
REGION := $(shell grep 'aws_region' $(TFVARS) 2>/dev/null | head -1 | sed 's/.*= *"\(.*\)"/\1/')

.PHONY: init plan apply destroy fast-destroy scale-down kubeconfig test clean

## Initialize Terraform
init:
	terraform init

## Plan changes
plan:
	terraform plan -var-file=$(TFVARS) -parallelism=$(PARALLELISM)

## Apply changes (high parallelism for speed)
apply:
	terraform apply -var-file=$(TFVARS) -parallelism=$(PARALLELISM)

## Auto-approve apply (use with caution)
apply-auto:
	terraform apply -var-file=$(TFVARS) -parallelism=$(PARALLELISM) -auto-approve

## Configure kubectl after cluster creation
kubeconfig:
	aws eks update-kubeconfig --name $(CLUSTER_NAME) --region $(REGION)

## Run infrastructure validation tests
test: kubeconfig
	kubectl apply -f test/
	@echo ""
	@echo "Waiting for test pods..."
	@sleep 15
	kubectl get pods -n infra-test
	@echo ""
	@echo "Pod-to-pod test:"
	@kubectl logs pod-to-pod-test -n infra-test 2>/dev/null || echo "(still running)"
	@echo ""
	@echo "External connectivity test:"
	@kubectl logs external-connectivity-test -n infra-test 2>/dev/null || echo "(still running)"

## Scale node groups to zero (speeds up destroy significantly)
scale-down:
	@echo "Scaling GPU node group to 0..."
	-aws eks update-nodegroup-config \
		--cluster-name $(CLUSTER_NAME) \
		--nodegroup-name $(CLUSTER_NAME)-gpu \
		--scaling-config minSize=0,maxSize=1,desiredSize=0 \
		--region $(REGION) 2>/dev/null
	@echo "Scaling system node group to min..."
	-aws eks update-nodegroup-config \
		--cluster-name $(CLUSTER_NAME) \
		--nodegroup-name $(CLUSTER_NAME)-system \
		--scaling-config minSize=0,maxSize=1,desiredSize=0 \
		--region $(REGION) 2>/dev/null
	@echo "Waiting 60s for nodes to drain..."
	@sleep 60

## Destroy with pre-scaling (faster teardown)
fast-destroy: scale-down
	@echo "Cleaning up test resources..."
	-kubectl delete -f test/ --ignore-not-found 2>/dev/null
	@echo "Running terraform destroy..."
	terraform destroy -var-file=$(TFVARS) -parallelism=$(PARALLELISM) -auto-approve

## Standard destroy (without pre-scaling)
destroy:
	@echo "Cleaning up test resources..."
	-kubectl delete -f test/ --ignore-not-found 2>/dev/null
	terraform destroy -var-file=$(TFVARS) -parallelism=$(PARALLELISM)

## Clean terraform state and caches
clean:
	rm -rf .terraform .terraform.lock.hcl
	rm -f tfplan

## Show current cluster info
info:
	@echo "Cluster: $(CLUSTER_NAME)"
	@echo "Region:  $(REGION)"
	@echo "Env:     $(ENV)"
	-@aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) --query 'cluster.{Status:status,Version:version,Endpoint:endpoint}' --output table 2>/dev/null

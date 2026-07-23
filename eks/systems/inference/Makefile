################################################################################
# Inference Platform - Makefile
#
# Provides ordered rollout and rollback of inference components to avoid
# dependency issues on destroy. Components are deployed bottom-up (tier1 first)
# and destroyed top-down (tier3 first).
#
# Usage:
#   make init                    # Initialize Terraform
#   make plan                    # Plan all changes
#   make apply                   # Apply all changes (ordered)
#   make destroy                 # Destroy all (reverse order)
#
#   make rollout-tier1           # Deploy tier 1 (gateway)
#   make rollout-tier2           # Deploy tier 2 (backends)
#   make rollout-tier3           # Deploy tier 3 (serving)
#   make rollout                 # Full ordered rollout (1 → 2 → 3)
#
#   make rollback-tier3          # Destroy tier 3 only
#   make rollback-tier2          # Destroy tier 2 only
#   make rollback-tier1          # Destroy tier 1 only
#   make rollback                # Full ordered rollback (3 → 2 → 1)
#
#   make rollback-component C=vllm   # Destroy a single component
#   make rollout-component C=vllm    # Rollout a single component
################################################################################

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Configuration
ENV          ?= dev
TFVARS       := dev-inf.tfvars
TF           := terraform
TF_FLAGS     := -var-file=$(TFVARS)
AUTO_APPROVE ?= false

ifeq ($(AUTO_APPROVE),true)
  APPROVE_FLAG := -auto-approve
else
  APPROVE_FLAG :=
endif

# Component → Terraform resource mapping
# Tier 1: Gateway
TIER1_TARGETS := \
  module.kgateway \
  module.envoy_ai_gateway

# Tier 2: Inference Backends
TIER2_TARGETS := \
  module.nvidia_operator \
  module.vllm \
  module.sglang

# Tier 3: Model Serving
TIER3_TARGETS := \
  module.kserve \
  module.bifrost

# Component name → target mapping (for single-component operations)
COMPONENT_MAP_kgateway         := module.kgateway
COMPONENT_MAP_envoy_ai_gateway := module.envoy_ai_gateway
COMPONENT_MAP_envoy            := module.envoy_ai_gateway
COMPONENT_MAP_nvidia_operator  := module.nvidia_operator
COMPONENT_MAP_nvidia           := module.nvidia_operator
COMPONENT_MAP_vllm             := module.vllm
COMPONENT_MAP_sglang           := module.sglang
COMPONENT_MAP_kserve           := module.kserve
COMPONENT_MAP_bifrost          := module.bifrost

################################################################################
# Core Terraform Commands
################################################################################

.PHONY: init
init: ## Initialize Terraform working directory
	$(TF) init

.PHONY: plan
plan: ## Plan all infrastructure changes
	$(TF) plan $(TF_FLAGS)

.PHONY: apply
apply: ## Apply all infrastructure changes
	$(TF) apply $(TF_FLAGS) $(APPROVE_FLAG)

.PHONY: destroy
destroy: rollback ## Destroy all (alias for rollback - ordered teardown)

.PHONY: validate
validate: ## Validate Terraform configuration
	$(TF) validate

.PHONY: fmt
fmt: ## Format Terraform files
	$(TF) fmt -recursive

.PHONY: output
output: ## Show Terraform outputs
	$(TF) output

################################################################################
# Ordered Rollout (Deploy: Tier 1 → Tier 2 → Tier 3)
################################################################################

.PHONY: rollout
rollout: rollout-tier1 rollout-tier2 rollout-tier3 ## Full ordered rollout (tier1 → tier2 → tier3)
	@echo "✅ Full rollout complete"

.PHONY: rollout-tier1
rollout-tier1: ## Deploy Tier 1: Gateway components
	@echo "🚀 Rolling out Tier 1: Gateway..."
	@for target in $(TIER1_TARGETS); do \
		echo "  → Applying $$target"; \
		$(TF) apply $(TF_FLAGS) -target="$$target" $(APPROVE_FLAG) || exit 1; \
	done
	@echo "✅ Tier 1 rollout complete"

.PHONY: rollout-tier2
rollout-tier2: ## Deploy Tier 2: Inference backends
	@echo "🚀 Rolling out Tier 2: Backends..."
	@for target in $(TIER2_TARGETS); do \
		echo "  → Applying $$target"; \
		$(TF) apply $(TF_FLAGS) -target="$$target" $(APPROVE_FLAG) || exit 1; \
	done
	@echo "✅ Tier 2 rollout complete"

.PHONY: rollout-tier3
rollout-tier3: ## Deploy Tier 3: Model serving
	@echo "🚀 Rolling out Tier 3: Serving..."
	@for target in $(TIER3_TARGETS); do \
		echo "  → Applying $$target"; \
		$(TF) apply $(TF_FLAGS) -target="$$target" $(APPROVE_FLAG) || exit 1; \
	done
	@echo "✅ Tier 3 rollout complete"

################################################################################
# Ordered Rollback (Destroy: Tier 3 → Tier 2 → Tier 1)
################################################################################

.PHONY: rollback
rollback: rollback-tier3 rollback-tier2 rollback-tier1 ## Full ordered rollback (tier3 → tier2 → tier1)
	@echo "✅ Full rollback complete"

.PHONY: rollback-tier3
rollback-tier3: ## Destroy Tier 3: Model serving
	@echo "🔄 Rolling back Tier 3: Serving..."
	@for target in $(TIER3_TARGETS); do \
		echo "  → Destroying $$target"; \
		$(TF) destroy $(TF_FLAGS) -target="$$target" $(APPROVE_FLAG) 2>/dev/null || true; \
	done
	@echo "✅ Tier 3 rollback complete"

.PHONY: rollback-tier2
rollback-tier2: ## Destroy Tier 2: Inference backends
	@echo "🔄 Rolling back Tier 2: Backends..."
	@for target in $(TIER2_TARGETS); do \
		echo "  → Destroying $$target"; \
		$(TF) destroy $(TF_FLAGS) -target="$$target" $(APPROVE_FLAG) 2>/dev/null || true; \
	done
	@echo "✅ Tier 2 rollback complete"

.PHONY: rollback-tier1
rollback-tier1: ## Destroy Tier 1: Gateway
	@echo "🔄 Rolling back Tier 1: Gateway..."
	@for target in $(TIER1_TARGETS); do \
		echo "  → Destroying $$target"; \
		$(TF) destroy $(TF_FLAGS) -target="$$target" $(APPROVE_FLAG) 2>/dev/null || true; \
	done
	@echo "✅ Tier 1 rollback complete"

################################################################################
# Single Component Operations
################################################################################

.PHONY: rollout-component
rollout-component: ## Deploy a single component (usage: make rollout-component C=vllm)
ifndef C
	$(error Usage: make rollout-component C=<component>. Valid: kgateway, envoy_ai_gateway, nvidia_operator, vllm, sglang, kserve, bifrost)
endif
	@target="$(COMPONENT_MAP_$(C))"; \
	if [ -z "$$target" ]; then \
		echo "❌ Unknown component: $(C)"; \
		echo "   Valid components: kgateway, envoy[_ai_gateway], nvidia[_operator], vllm, sglang, kserve, bifrost"; \
		exit 1; \
	fi; \
	echo "🚀 Rolling out component: $(C) ($$target)"; \
	$(TF) apply $(TF_FLAGS) -target="$$target" $(APPROVE_FLAG)

.PHONY: rollback-component
rollback-component: ## Destroy a single component (usage: make rollback-component C=vllm)
ifndef C
	$(error Usage: make rollback-component C=<component>. Valid: kgateway, envoy_ai_gateway, nvidia_operator, vllm, sglang, kserve, bifrost)
endif
	@target="$(COMPONENT_MAP_$(C))"; \
	if [ -z "$$target" ]; then \
		echo "❌ Unknown component: $(C)"; \
		echo "   Valid components: kgateway, envoy[_ai_gateway], nvidia[_operator], vllm, sglang, kserve, bifrost"; \
		exit 1; \
	fi; \
	echo "🔄 Rolling back component: $(C) ($$target)"; \
	$(TF) destroy $(TF_FLAGS) -target="$$target" $(APPROVE_FLAG)

################################################################################
# Status & Debugging
################################################################################

.PHONY: status
status: ## Show deployment status of all components
	@echo "📊 Inference Platform Status:"
	@echo "─────────────────────────────────────"
	@$(TF) output 2>/dev/null || echo "  (run 'make apply' first)"

.PHONY: state-list
state-list: ## List all resources in Terraform state
	@$(TF) state list 2>/dev/null | sort

.PHONY: refresh
refresh: ## Refresh Terraform state from live infrastructure
	$(TF) refresh $(TF_FLAGS)

################################################################################
# Workspace Management
################################################################################

.PHONY: workspace-list
workspace-list: ## List Terraform workspaces
	$(TF) workspace list

.PHONY: workspace-new
workspace-new: ## Create a new workspace (usage: make workspace-new W=staging)
ifndef W
	$(error Usage: make workspace-new W=<workspace-name>)
endif
	$(TF) workspace new $(W)

.PHONY: workspace-select
workspace-select: ## Select a workspace (usage: make workspace-select W=dev)
ifndef W
	$(error Usage: make workspace-select W=<workspace-name>)
endif
	$(TF) workspace select $(W)

################################################################################
# Help
################################################################################

.PHONY: help
help: ## Show this help message
	@echo "Inference Platform - Makefile Commands"
	@echo "══════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Configuration:"
	@echo "  ENV=$(ENV)  TFVARS=$(TFVARS)  AUTO_APPROVE=$(AUTO_APPROVE)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Components (for C= parameter):"
	@echo "  kgateway, envoy[_ai_gateway], nvidia[_operator], vllm, sglang, kserve, bifrost"
	@echo ""
	@echo "Examples:"
	@echo "  make rollout                          # Deploy everything in order"
	@echo "  make rollback                         # Tear down everything safely"
	@echo "  make rollout-tier2                    # Deploy only tier 2"
	@echo "  make rollback-component C=vllm        # Remove just vllm"
	@echo "  make apply AUTO_APPROVE=true          # Apply without prompts"

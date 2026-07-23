# Backend Configuration Template
# This file provides the template for remote state configuration
# Actual backend configuration should be provided via backend config files

# Example backend configuration for different environments:
# 
# For development environment (backend-dev.hcl):
# bucket         = "ml-platform-terraform-state-dev"
# key            = "infrastructure/terraform.tfstate"
# region         = "us-west-2"
# dynamodb_table = "ml-platform-terraform-locks-dev"
# encrypt        = true
#
# For production environment (backend-prod.hcl):
# bucket         = "ml-platform-terraform-state-prod"
# key            = "infrastructure/terraform.tfstate"
# region         = "us-west-2"
# dynamodb_table = "ml-platform-terraform-locks-prod"
# encrypt        = true

# Usage:
# terraform init -backend-config=backend-dev.hcl
# terraform init -backend-config=backend-prod.hcl
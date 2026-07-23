# Development Environment Backend Configuration
# Use this file to configure remote state for the development environment
# Usage: terraform init -backend-config=backend-configs/backend-dev.hcl

bucket         = "ml-platform-terraform-state-dev"
key            = "infrastructure/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "ml-platform-terraform-locks-dev"
encrypt        = true
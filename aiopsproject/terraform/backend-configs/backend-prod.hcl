# Production Environment Backend Configuration
# Use this file to configure remote state for the production environment
# Usage: terraform init -backend-config=backend-configs/backend-prod.hcl

bucket         = "ml-platform-terraform-state-prod"
key            = "infrastructure/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "ml-platform-terraform-locks-prod"
encrypt        = true
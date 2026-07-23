# Backend configuration for remote state storage
# Uncomment and configure the values below to use S3 backend for state storage
# This enables team collaboration and state locking

# terraform {
#   backend "s3" {
#     bucket         = "my-terraform-state-bucket"  # Replace with your S3 bucket name
#     key            = "eks/terraform.tfstate"      # Path within the bucket
#     region         = "us-east-1"                  # AWS region for the state bucket
#     encrypt        = true                         # Enable encryption at rest
#     dynamodb_table = "terraform-state-lock"       # DynamoDB table for state locking
#   }
# }

# To use this backend:
# 1. Create an S3 bucket for state storage with versioning enabled
# 2. Create a DynamoDB table with a primary key named "LockID" (String type)
# 3. Uncomment the backend block above and update the values
# 4. Run `terraform init` to migrate state to the remote backend

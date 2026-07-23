provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs            = slice(data.aws_availability_zones.available.names, 0, 3)
  create_vpc     = var.vpc_id == null
  vpc_id         = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  private_subnets = local.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
}

# Validate that private_subnet_ids is provided when using an existing VPC
resource "terraform_data" "validate_subnets" {
  count = var.vpc_id != null && length(var.private_subnet_ids) == 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(var.private_subnet_ids) > 0
      error_message = "private_subnet_ids must be provided when vpc_id is set."
    }
  }
}

# --- VPC (only created when vpc_id is not provided) ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  count = local.create_vpc ? 1 : 0

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

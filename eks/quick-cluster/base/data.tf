################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

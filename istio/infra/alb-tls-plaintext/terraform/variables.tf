variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Domain name for the ACM certificate (e.g., *.example.com)"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional SANs for the ACM certificate"
  type        = list(string)
  default     = []
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name for DNS validation (e.g., example.com)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "istio-alb-plaintext"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

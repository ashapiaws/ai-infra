variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "dev-cluster-tf-01"
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_id" {
  description = "ID of the VPC where to create the cluster"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the nodes/node groups will be provisioned"
  type        = list(string)
  default     = ["subnet-051b1804545a4e3d3", "subnet-099b951fa3e709a3b"]
}

variable "node_group_instance_types" {
  description = "List of instance types associated with the EKS Node Group"
  type        = list(string)
  default     = ["g6e.12xlarge"]
}

variable "node_group_ami_id" {
  description = "The AMI from which to launch the instance"
  type        = string
  default     = "ami-069c5809e5462c776"
}

variable "placement_group_name" {
  description = "The name of the placement group"
  type        = string
  default     = "test-rack-01"
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    env         = "dev"
    role        = "compute"
    team        = "ops-team"
    auto-delete = "no"
  }
}
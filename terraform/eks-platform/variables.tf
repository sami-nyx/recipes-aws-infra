variable "common_tags" {
  type        = map(string)
  description = "A map of default tags to assign to all AWS resources created by Terraform."
  default = {
    owner     = "terraform-eks"
    managedBy = "terraform"
    usage     = "training"
    app_name  = "app_name"
    env       = "staging"
  }
}

variable "region" {
  type        = string
  description = "The target AWS region for deploying all infrastructure resources."
}

variable "vpc_cidrs" {
  type        = string
  description = "The CIDR block allocation for the VPC."
}

variable "ha" {
  type        = number
  description = "High availability factor or number of availability zones to span across."
}

variable "nodes_in_public" {
  type        = bool
  description = "If true, nodes deploy in public subnets (saves money by avoiding NAT gateway). If false, deploys private subnets + NAT gateway."
  default     = true
}

variable "node_type" {
  type        = string
  description = "The EC2 instance type to use for the EKS managed node groups."
}

variable "node_counts" {
  type = object({
    min     = number
    desired = number
    max     = number
  })
  description = "Scaling limits (min, desired, max node counts) for the EKS managed node group."
}

variable "environment" {
  type        = string
  description = "The deployment environment name (e.g., staging, production)."
}

variable "principal_arn" {
  type        = string
  description = "The primary IAM principal ARN granted administrator access to the EKS cluster."
}

variable "bootstrap_role_arn" {
  type        = string
  description = "The secondary IAM role or user ARN used for cluster bootstrapping and administrative access."
}

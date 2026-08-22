variable "owner" {
  type        = string
  description = "The owner or team name used as a prefix for naming the EKS cluster."
}



variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where the EKS cluster is provisioned."
}

variable "node_type" {
  type        = string
  description = "The EC2 instance type to use for the EKS node group."
}

variable "name_prefix" {
  type        = string
  description = "A prefix used for naming associated AWS resources like IAM roles."
}

variable "node_counts" {
  type = object({
    min     = number
    desired = number
    max     = number
  })
  description = "Scaling configuration for the EKS node group defining min, desired, and max capacities."

  validation {
    condition     = var.node_counts.min <= var.node_counts.desired && var.node_counts.desired <= var.node_counts.max
    error_message = "Node count sizing error: Must satisfy 'min <= desired <= max'."
  }
}

variable "principal_arn" {
  type        = string
  description = "The IAM principal ARN to be granted administrator access to the EKS cluster."
}

variable "bootstrap_role_arn" {
  type        = string
  description = "The IAM role or user ARN for bootstrapping administrative cluster access."
}

variable "region" {
  type        = string
  description = "The AWS region where the EKS cluster and its resources will be created."
}

variable "nodes_in_public" {
  type = bool
}
variable "public_subnet_ids" {

}

variable "private_subnet_ids" {

}
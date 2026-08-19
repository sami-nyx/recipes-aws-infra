variable "vpc_id" {
  type        = string
  description = "VPC ID from networking module"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}
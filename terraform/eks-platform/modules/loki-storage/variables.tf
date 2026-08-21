variable "environment" {
  type        = string
  description = "The deployment environment name (e.g., dev, staging, prod) used for tagging and resource naming."
}

variable "oidc_provider_arn" {
  type        = string
  description = "The Amazon Resource Name (ARN) of the IAM OIDC provider, typically used for configuring IAM Roles for Service Accounts (IRSA)."
}
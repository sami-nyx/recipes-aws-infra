
variable "region" {

}
variable "cluster_name" {

}
variable "name_prefix" {
  type = string
}
variable "oidc_provider_arn" {

}
variable "region" {
  type        = string
  description = "The AWS region where secrets manager resources are located and policies are applied."
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster where the External Secrets Operator is deployed."
}

variable "name_prefix" {
  type        = string
  description = "A prefix used for naming associated AWS resources like IAM policies and roles."
}

variable "oidc_provider_arn" {
  type        = string
  description = "The Amazon Resource Name (ARN) of the IAM OIDC provider used for IRSA integration."
}

variable "eks-runner-subject-claim-string" {

}
variable "environment" {
  type = string
}

variable "region" {
  type        = string
  description = "The AWS region the EKS cluster runs in, used to scope this role's EKS/CloudWatch permissions to that cluster only."
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster this role is allowed to manage, used to scope its EKS/CloudWatch permissions."
}

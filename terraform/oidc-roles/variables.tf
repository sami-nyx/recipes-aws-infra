
variable "role_name" {
  type = string
}
variable "subject_claim_string" {
  type = string
}

variable "eks_controller_role_name" {
  type = string
}
variable "s3_push_role_name" {

}

variable "cloud_front_distro_id" {

}

variable "eks-runner-subject-claim-string" {
  default = "repo:sami-nyx@56940788/recipes-aws-infra@1338901930/*"
}
variable "environment" {
  default = "staging"
}
# tf-state-bucket-eks-platform-recipes
module "ecr_push_role" {
  source               = "./modules/ecr-push"
  subject_claim_string = var.subject_claim_string
  role_name            = var.role_name
}

module "eks_controller_role" {
  source               = "./modules/eks-controller"
  subject_claim_string = var.subject_claim_string
  role_name            = var.eks_controller_role_name
}
module "s3_push_role" {
  source                = "./modules/s3-push-role"
  subject_claim_string  = var.subject_claim_string
  role_name             = var.s3_push_role_name
  cloud_front_distro_id = var.cloud_front_distro_id
}

module "ecr_push_role" {
  source               = "./modules/ecr-push"
  subject_claim_string = var.subject_claim_string
  role_name            = var.role_name
}

module "s3_push_role" {
  source                = "./modules/s3-push-role"
  subject_claim_string  = var.subject_claim_string
  role_name             = var.s3_push_role_name
  cloud_front_distro_id = var.cloud_front_distro_id
}

module "eks_runner" {
  source                          = "./modules/eks-runner"
  environment                     = var.environment
  eks-runner-subject-claim-string = var.eks-runner-subject-claim-string

}

module "cluster_bootstrap" {
  source                       = "./modules/cluster-bootstrap"
  cluster_name                 = var.cluster_name
  region                       = var.region
  github_actions_subject_claim = var.eks-runner-subject-claim-string
}
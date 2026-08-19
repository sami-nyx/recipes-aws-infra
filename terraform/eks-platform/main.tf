locals {
  name_prefix = "${var.common_tags.owner}-${var.common_tags.app_name}"
}

module "network" {
  source      = "./modules/network"
  name_prefix = local.name_prefix
  vpc_cidrs   = var.vpc_cidrs
  ha          = var.ha
}


module "eks_core" {
  source             = "./modules/eks-core"
  owner              = var.common_tags.owner
  subnet_ids         = module.network.subnet_ids
  vpc_id             = module.network.vpc_id
  node_type          = var.node_type
  name_prefix        = local.name_prefix
  node_counts        = var.node_counts
  principal_arn      = var.principal_arn
  bootstrap_role_arn = var.bootstrap_role_arn

}
module "cluster_roles" {
  source            = "./modules/cluster-rloes"
  region            = var.region
  cluster_name      = module.eks_core.cluster_name
  name_prefix       = local.name_prefix
  oidc_provider_arn = module.eks_core.oidc_provider_arn

}

module "loki_storege" {
  source            = "./modules/loki-storage"
  environment       = var.environment
  oidc_provider_arn = module.eks_core.oidc_provider_arn
}
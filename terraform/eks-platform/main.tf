locals {
  name_prefix = "${var.common_tags.owner}-${var.common_tags.app_name}"
}

module "network" {
  source          = "./modules/network"
  name_prefix     = local.name_prefix
  vpc_cidrs       = var.vpc_cidrs
  ha              = var.ha
  nodes_in_public = var.nodes_in_public
}


module "eks_core" {
  source             = "./modules/eks-core"
  owner              = var.common_tags.owner
  vpc_id             = module.network.vpc_id
  node_type          = var.node_type
  name_prefix        = local.name_prefix
  node_counts        = var.node_counts
  principal_arn      = var.principal_arn
  bootstrap_role_arn = var.bootstrap_role_arn
  region             = var.region
  nodes_in_public    = var.nodes_in_public
  private_subnet_ids = module.network.privete_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids
  depends_on         = [module.network]
}

module "loki_storege" {
  source            = "./modules/loki-storage"
  environment       = var.environment
  oidc_provider_arn = module.eks_core.oidc_provider_arn
}

module "rds" {
  source = "./modules/rds"

  private_subnet_ids = module.network.privete_subnet_ids
  vpc_id             = module.network.vpc_id
  node_sg_id         = module.eks_core.node_sg_id

  db_engine                  = var.db_engine
  db_engine_version          = var.db_engine_version
  db_allocated_storage       = var.db_allocated_storage
  db_name                    = var.db_name
  db_instance_class           = var.db_instance_class
  db_username                 = var.db_username
  db_skip_final_snapshot     = var.db_skip_final_snapshot
  db_backup_retention_period = var.db_backup_retention_period
  db_deletion_protection     = var.db_deletion_protection
}

module "cluster_roles" {
  source            = "./modules/cluster-rloes"
  region            = var.region
  cluster_name      = module.eks_core.cluster_name
  name_prefix       = local.name_prefix
  oidc_provider_arn = module.eks_core.oidc_provider_arn
  db_master_user_secret_arn = module.rds.db_master_user_secret_arn
}

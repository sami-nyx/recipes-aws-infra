
module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "~> 21.25.0"
  name               = "${var.owner}-cluster"
  kubernetes_version = "1.36"
  subnet_ids         = var.subnet_ids
  vpc_id             = var.vpc_id
  enable_irsa        = true

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    main = {
      name         = "${var.owner}-eks-node"
      desired_size = var.node_counts.desired
      max_size     = var.node_counts.max
      min_size     = var.node_counts.min

      instance_types = [var.node_type]
    }
  }
}
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.24.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.arn
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }
  # enable_metrics_server = true
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  name                  = "${var.name_prefix}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
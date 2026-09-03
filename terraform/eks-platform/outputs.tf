output "eks_node_group_name" {
  value = module.eks_core.eks_managed_node_group
}
output "cluster_name" {
  value = module.eks_core.cluster_name
}

output "ebs_csi_irsa_role_name" {
  value = module.eks_core.ebs_csi_irsa_role_name
}

output "external_secrets_role_arn" {
  value = module.cluster_roles.external_secrets_role_arn
}
output "loki_irsa_role_arn" {
  value = module.loki_storage.loki_irsa_role_arn
}

output "cert_manager_route53_role_arn" {
  value = module.cluster_roles.cert_manager_route53_role_arn
}

output "cloudfront_sync_role_arn" {
  value = module.cluster_roles.cloudfront_sync_role_arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_core.cluster_name}"
}
output "cluster_region" {
  value = var.region
}

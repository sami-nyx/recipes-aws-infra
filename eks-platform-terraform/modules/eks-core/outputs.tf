# output "cluster_certificate_authority_data" {
#   value = module.eks.cluster_certificate_authority_data
# }
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "cluster_name" {
  value = module.eks.cluster_name
}
output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "eks_managed_node_group" {
  value = module.eks.eks_managed_node_groups["main"].node_group_id
}
output "ebs_csi_irsa_role_name" {
  value = module.ebs_csi_irsa_role.name
}
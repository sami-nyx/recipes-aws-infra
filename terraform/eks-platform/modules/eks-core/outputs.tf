
output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}
output "cluster_name" {
  value = aws_eks_cluster.this.name
}
output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "eks_managed_node_group" {
  value = aws_eks_node_group.default.id
}
output "ebs_csi_irsa_role_name" {
  value = aws_iam_role.ebs_csi.name
}
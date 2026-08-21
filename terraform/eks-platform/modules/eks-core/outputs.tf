output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "The endpoint URL for the Kubernetes API server of the EKS cluster."
}

output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "The name of the provisioned Amazon EKS cluster."
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.eks.arn
  description = "The ARN of the IAM OIDC identity provider associated with the EKS cluster."
}

output "eks_managed_node_group" {
  value       = aws_eks_node_group.default.id
  description = "The ID/name of the managed EKS node group."
}

output "ebs_csi_irsa_role_name" {
  value       = aws_iam_role.ebs_csi.name
  description = "The name of the IAM role used by the EBS CSI driver via IRSA (IAM Roles for Service Accounts)."
}
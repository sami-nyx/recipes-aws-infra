

resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_entry" "bootstrap_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.bootstrap_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin_policy" {
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.cluster_admin.principal_arn

  access_scope {
    type = "cluster"
  }
}
resource "aws_eks_access_policy_association" "bootstrap_admin_policy" {
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.bootstrap_admin.principal_arn

  access_scope {
    type = "cluster"
  }
}
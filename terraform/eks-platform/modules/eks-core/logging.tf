# ==============================================================================
# Secrets encryption (KMS) + control-plane audit logging
# ==============================================================================
# Neither was configured before: Kubernetes Secrets sat in etcd with only
# AWS's default (non-customer-managed) encryption, and there was no audit
# trail of who called the EKS API. Both are cheap to add and matter a lot
# for incident response.

resource "aws_kms_key" "eks_secrets" {
  description             = "Envelope encryption key for ${local.cluster_name} Kubernetes secrets"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.name_prefix}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  # EKS auto-creates a log group at exactly this path the first time
  # cluster logging is enabled. Pre-creating it lets us set a retention
  # period; otherwise CloudWatch keeps these logs forever.
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 90
}

data "aws_caller_identity" "current" {}
# --------------------------------------------------------------------------------------------------
# IAM Policy for Secrets Manager Access
# --------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "external_secrets_policy" {
  name        = "${var.name_prefix}-external-secrets-policy"
  description = "Allows External Secrets Operator to read secrets from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:prod/recipes/api-keys-*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:godaddy-api-credentials*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:recipes-gitops-pat*",


        ]
      }
    ]
  })
}


# --------------------------------------------------------------------------------------------------
# IRSA Role for External Secrets Operator
# --------------------------------------------------------------------------------------------------
module "external_secrets_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  name = "${var.name_prefix}-external-secrets"

  policies = {
    policy = aws_iam_policy.external_secrets_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn = var.oidc_provider_arn

      namespace_service_accounts = [
        "external-secrets:external-secrets"
      ]
    }
  }
}

# # --------------------------------------------------------------------------------------------------
# # Fetch Existing GitHub Actions IAM Role (Fails if role does not exist in AWS)
# # --------------------------------------------------------------------------------------------------
# data "aws_iam_role" "github_actions" {
#   name = "gh-actions-eks-update-kube-config-role"
# }
# # --------------------------------------------------------------------------------------------------
# # EKS Access Entry for GitHub Actions Runner
# # --------------------------------------------------------------------------------------------------
# resource "aws_eks_access_entry" "github_actions" {
#   cluster_name  = var.cluster_name # Updated to reference your cluster name
#   principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/gh-actions-eks-update-kube-config-role"
#   type          = "STANDARD"
# }

# resource "aws_eks_access_policy_association" "github_actions" {
#   cluster_name  = var.cluster_name
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#   principal_arn = aws_eks_access_entry.github_actions.principal_arn

#   access_scope {
#     type = "cluster"
#   }
# }
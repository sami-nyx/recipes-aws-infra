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

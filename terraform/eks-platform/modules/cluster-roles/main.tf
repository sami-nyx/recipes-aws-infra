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
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:recipes-gitops-pat*",
          # Alertmanager's Slack receiver. A separate secret from the
          # SLACK_WEBHOOK_URL GitHub Actions secret CI already uses -
          # not readable from inside the cluster regardless (GitHub
          # secrets are write-only, even to us), and kept structurally
          # independent even though the value starts out identical, so
          # either one can change without touching the other.
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:recipes-alertmanager-slack-webhook*"
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


# --------------------------------------------------------------------------------------------------
# IRSA Role for cert-manager's Route53 DNS-01 solver
# --------------------------------------------------------------------------------------------------
# The hosted zone itself is deliberately NOT managed here - it's created
# manually (AWS Console/CLI), same as it's replacing a manual GoDaddy DNS
# setup, and this stack only owns cluster bootstrap + the IRSA roles
# workloads need. var.route53_zone_id is just a value, supplied once the
# zone exists - Terraform never creates, reads, or depends on the zone
# resource itself. cert-manager's actual ClusterIssuer config (which
# solver to use, the role to assume) lives in the GitOps repo as an Argo
# CD-managed resource, same as it already did for the GoDaddy webhook
# this replaces - only the IAM side moves here, to match every other
# IRSA role in this project.
#
# Replaces the GoDaddy webhook + its API-key secret entirely - cert-manager
# has native Route53 support, so no third-party chart or long-lived API
# credential is needed at all, just IRSA like every other in-cluster AWS
# access in this project. Scoped to only this one hosted zone, not
# account-wide Route53 access.
resource "aws_iam_policy" "cert_manager_route53_policy" {
  name        = "${var.name_prefix}-cert-manager-route53-policy"
  description = "Allows cert-manager to complete Route53 DNS-01 challenges for one hosted zone, and nothing else"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZonesByName"]
        Resource = "*"
      }
    ]
  })
}

module "cert_manager_route53_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  name = "${var.name_prefix}-cert-manager-route53"

  policies = {
    policy = aws_iam_policy.cert_manager_route53_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn = var.oidc_provider_arn

      namespace_service_accounts = [
        "cert-manager:cert-manager"
      ]
    }
  }
}

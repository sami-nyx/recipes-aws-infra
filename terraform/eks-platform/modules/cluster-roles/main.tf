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


# --------------------------------------------------------------------------------------------------
# IRSA Role for the cloudfront-sync Argo CD sync-hook Job
# --------------------------------------------------------------------------------------------------
# Same shape as cert-manager's Route53 role above: this stack only owns
# the IAM side, the Job itself (an Argo CD PreSync hook, deleted and
# recreated on every sync - same pattern recipes-api-db-init already
# uses, so it actually re-runs on every apply, not just once) lives in
# recipes-gitops as apps/cloudfront-sync.
#
# Exists because ingress-nginx's LoadBalancer Service gets a brand new
# ELB - and therefore a brand new DNS name - every time this stack is
# destroyed and re-applied (this project's own normal daily cycle, not
# an edge case), and CloudFront's origin doesn't update itself to
# match. var.cloudfront_distribution_id is just a value, supplied once
# the distribution exists - same treatment as var.route53_zone_id,
# Terraform never creates or depends on the distribution itself.
resource "aws_iam_policy" "cloudfront_sync_policy" {
  name        = "${var.name_prefix}-cloudfront-sync-policy"
  description = "Allows finding the current ingress-nginx ELB and pointing one CloudFront distribution's origin at it, and nothing else"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution"
        ]
        # CloudFront IAM does support resource-level scoping, unlike
        # the two actions below - scoped to exactly one distribution,
        # not account-wide CloudFront access.
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${var.cloudfront_distribution_id}"
      },
      {
        Effect = "Allow"
        # Neither of these supports resource-level scoping in AWS's
        # IAM model at all - both are read-only, account/region-wide,
        # by necessity, not by choice.
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

module "cloudfront_sync_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  name = "${var.name_prefix}-cloudfront-sync"

  policies = {
    policy = aws_iam_policy.cloudfront_sync_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn = var.oidc_provider_arn

      namespace_service_accounts = [
        "cloudfront-sync:cloudfront-sync"
      ]
    }
  }
}

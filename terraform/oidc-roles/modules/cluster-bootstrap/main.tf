data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# ------------------------------------------------------------------------------
# GitHub Actions OIDC Trust
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        data.aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        var.github_actions_subject_claim
      ]
    }
  }
}

# ------------------------------------------------------------------------------
# EKS Access
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_access" {
  statement {
    effect = "Allow"

    actions = [
      "eks:DescribeCluster"
    ]

    resources = [
      "arn:${local.partition}:eks:${var.region}:${local.account_id}:cluster/${var.cluster_name}"
    ]
  }
}

# ------------------------------------------------------------------------------
# IAM Policy
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "bootstrap" {
  name        = "github-actions-bootstrap"
  description = "Allows GitHub Actions to authenticate to the EKS cluster for platform bootstrap"

  policy = data.aws_iam_policy_document.eks_access.json
}

# ------------------------------------------------------------------------------
# GitHub Actions Bootstrap Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_bootstrap" {
  name = "github-actions-bootstrap"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  max_session_duration = 3600
}

# ------------------------------------------------------------------------------
# Attach Policy
# ------------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "bootstrap" {
  role       = aws_iam_role.github_actions_bootstrap.name
  policy_arn = aws_iam_policy.bootstrap.arn
}

# ------------------------------------------------------------------------------
# EKS Access Entry
#
# This is what gives the bootstrap role permission inside Kubernetes.
# ------------------------------------------------------------------------------

resource "aws_eks_access_entry" "bootstrap" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.github_actions_bootstrap.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bootstrap_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.github_actions_bootstrap.arn

  policy_arn = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
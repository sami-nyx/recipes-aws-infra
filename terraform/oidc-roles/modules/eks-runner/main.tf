data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  terraform_state_bucket = "tf-state-bucket-eks-platform-recipes"
  terraform_state_key    = "${var.environment}/terraform.tfstate"

  loki_bucket = "recipes-app-loki-logs-${var.environment}"
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
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "${var.eks-runner-subject-claim-string}"
      ]
    }
  }
}

# ------------------------------------------------------------------------------
# 1. Terraform State
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "terraform_state" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "arn:${local.partition}:s3:::${local.terraform_state_bucket}"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:${local.partition}:s3:::${local.terraform_state_bucket}/${local.terraform_state_key}",
      "arn:${local.partition}:s3:::${local.terraform_state_bucket}/${local.terraform_state_key}.tflock"
    ]
  }
}

# ------------------------------------------------------------------------------
# 2. VPC / Networking
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "networking" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:*"
    ]

    resources = ["*"]
  }
}

# ------------------------------------------------------------------------------
# 3. EKS
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "eks" {
  statement {
    effect = "Allow"

    actions = [
      "eks:*"
    ]

    resources = ["*"]
  }
}

# ------------------------------------------------------------------------------
# 4. IAM
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "iam" {
  statement {
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListRoles",
      "iam:ListPolicies",

      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",

      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",

      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",

      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint"
    ]

    resources = ["*"]
  }

  # Terraform must be able to give EKS/EC2 the IAM roles it creates.
  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:${local.partition}:iam::${local.account_id}:role/*"
    ]
  }
}

# ------------------------------------------------------------------------------
# 5. Loki S3 Storage
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "loki_storage" {
  statement {
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging"
    ]

    resources = [
      "arn:${local.partition}:s3:::${local.loki_bucket}"
    ]
  }
}

# ------------------------------------------------------------------------------
# 6. Supporting EKS Resources
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_support" {
  statement {
    effect = "Allow"

    actions = [
      "logs:*",
      "kms:*"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:CreateServiceLinkedRole"
    ]

    resources = ["*"]
  }
}

# ------------------------------------------------------------------------------
# IAM Policies
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "terraform_state" {
  name   = "github-actions-terraform-state"
  policy = data.aws_iam_policy_document.terraform_state.json
}

resource "aws_iam_policy" "networking" {
  name   = "github-actions-networking"
  policy = data.aws_iam_policy_document.networking.json
}

resource "aws_iam_policy" "eks" {
  name   = "github-actions-eks"
  policy = data.aws_iam_policy_document.eks.json
}

resource "aws_iam_policy" "iam" {
  name   = "github-actions-iam"
  policy = data.aws_iam_policy_document.iam.json
}

resource "aws_iam_policy" "loki_storage" {
  name   = "github-actions-loki-storage"
  policy = data.aws_iam_policy_document.loki_storage.json
}

resource "aws_iam_policy" "eks_support" {
  name   = "github-actions-eks-support"
  policy = data.aws_iam_policy_document.eks_support.json
}

# ------------------------------------------------------------------------------
# GitHub Actions Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_terraform" {
  name               = "github-actions-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  max_session_duration = 3600
}

# ------------------------------------------------------------------------------
# Attach policies
# ------------------------------------------------------------------------------

locals {
  github_actions_policies = {
    terraform_state = aws_iam_policy.terraform_state.arn
    networking      = aws_iam_policy.networking.arn
    eks             = aws_iam_policy.eks.arn
    iam             = aws_iam_policy.iam.arn
    loki_storage    = aws_iam_policy.loki_storage.arn
    eks_support     = aws_iam_policy.eks_support.arn
  }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = local.github_actions_policies

  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = each.value
}
data "aws_caller_identity" "current" {}

# 2. Look up the existing OIDC provider in your account
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}
# 1. Trust Relationship Policy (Assume Role Document)
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

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
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.subject_claim_string]
    }
  }
}

data "aws_iam_policy_document" "s3_static_hosting_deploy" {
  # Permission to list the bucket contents (required for 'aws s3 sync')
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::recipes-ui-static-hosting"
    ]
  }

  # Permissions to upload, read, and delete files in the bucket
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::recipes-ui-static-hosting/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation"
    ]
    resources = [
      "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${var.cloud_front_distro_id}"
    ]
  }
}
# 3. IAM Role
resource "aws_iam_role" "github_actions_s3_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# 4. IAM Managed Policy
resource "aws_iam_policy" "s3_push_policy" {
  name        = "github-actions-s3-policy"
  description = "Allows s3 bucket push access for GitHub Actions"
  policy      = data.aws_iam_policy_document.s3_static_hosting_deploy.json
}

# 5. Attach Policy to Role
resource "aws_iam_role_policy_attachment" "attach_ecr_policy" {
  role       = aws_iam_role.github_actions_s3_role.name
  policy_arn = aws_iam_policy.s3_push_policy.arn
}
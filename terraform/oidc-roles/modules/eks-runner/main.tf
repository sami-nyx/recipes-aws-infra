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

  # Matches the bucket name pattern from modules/loki-storage
  # ("recipes-app-loki-logs-${environment}") - the only bucket this
  # stack's Terraform run actually needs to manage.
  loki_bucket_pattern = "recipes-app-loki-logs-*"
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
        var.eks-runner-subject-claim-string
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
# 2. Networking
# ------------------------------------------------------------------------------
# NOTE: this used to be a blanket "ec2:*" on "*". The action list below is
# scoped to what modules/network + the EKS node group actually call, but
# Resource has to stay "*" - most EC2 write APIs (CreateVpc, CreateSubnet,
# security-group rule changes, etc.) don't support resource-level IAM
# conditions. If a future `terraform apply` here fails with AccessDenied for
# another ec2:* action, add that specific action - don't fall back to "ec2:*".
data "aws_iam_policy_document" "networking" {
  statement {
    effect = "Allow"

    actions = [
      # VPC
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:ModifyVpcAttribute",
      # Subnets
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:DescribeSubnets",
      "ec2:ModifySubnetAttribute",
      # Internet Gateway
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:DescribeInternetGateways",
      # Route tables / routes
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:DescribeRouteTables",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:ReplaceRouteTableAssociation",
      # EIP / NAT gateway
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:DescribeNatGateways",
      # Security groups (EKS creates/manages these for the cluster + node group)
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      # Launch templates (EKS managed node groups own one per node group)
      "ec2:CreateLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      # Read-only / tagging needed throughout
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]

    resources = ["*"]
  }
}

# ------------------------------------------------------------------------------
# 3. EKS
# ------------------------------------------------------------------------------
# Scoped to this one cluster instead of every cluster in the account.

data "aws_iam_policy_document" "eks" {
  statement {
    effect = "Allow"

    actions = [
      "eks:*"
    ]

    resources = [
      "arn:${local.partition}:eks:${var.region}:${local.account_id}:cluster/${var.cluster_name}",
      "arn:${local.partition}:eks:${var.region}:${local.account_id}:nodegroup/${var.cluster_name}/*/*",
      "arn:${local.partition}:eks:${var.region}:${local.account_id}:addon/${var.cluster_name}/*/*",
      "arn:${local.partition}:eks:${var.region}:${local.account_id}:access-entry/${var.cluster_name}/*",
    ]
  }

  # A handful of EKS read calls (list/describe-available-versions style)
  # aren't tied to a specific cluster ARN and require Resource "*".
  statement {
    effect = "Allow"

    actions = [
      "eks:ListClusters",
      "eks:DescribeAddonVersions",
    ]

    resources = ["*"]
  }
}

# ------------------------------------------------------------------------------
# 4. IAM / IRSA
# ------------------------------------------------------------------------------
# NOTE: this is narrower than the old "iam:Create*/Delete*/Update*/Put*
# /Attach*/Detach*" wildcard, but Resource is still "role/*" and "policy/*"
# account-wide - IAM doesn't let you scope CreateRole to a not-yet-existing
# role name. That means this role can still create a new role and attach an
# AWS-managed policy to it (a privilege-escalation path). Closing that fully
# needs a permissions-boundary condition on iam:CreateRole shared with the
# eks-platform stack - flagged as a follow-up, not done here.

data "aws_iam_policy_document" "iam" {
  statement {
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]

    resources = [
      "arn:${local.partition}:iam::${local.account_id}:role/*",
      "arn:${local.partition}:iam::${local.account_id}:policy/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
    ]

    resources = [
      "arn:${local.partition}:iam::${local.account_id}:oidc-provider/*",
    ]
  }

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
# 5. S3
# ------------------------------------------------------------------------------
# NOTE: this used to be "s3:*" on every bucket in the account. This stack
# only ever manages the Loki storage bucket - scope to that.

data "aws_iam_policy_document" "s3" {
  statement {
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging",
      "s3:ListBucket",
    ]

    resources = [
      "arn:${local.partition}:s3:::${local.loki_bucket_pattern}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "arn:${local.partition}:s3:::${local.loki_bucket_pattern}/*",
    ]
  }
}

# ------------------------------------------------------------------------------
# 6. Supporting EKS Services
# ------------------------------------------------------------------------------
# Dropped "cloudformation:*" entirely - nothing in this repo creates
# CloudFormation stacks.

data "aws_iam_policy_document" "eks_support" {
  # CloudWatch log group for EKS control-plane logging, scoped to this
  # cluster's log group.
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
    ]

    resources = [
      "arn:${local.partition}:logs:${var.region}:${local.account_id}:log-group:/aws/eks/${var.cluster_name}*",
      "arn:${local.partition}:logs:${var.region}:${local.account_id}:log-group:/aws/eks/${var.cluster_name}*:*",
    ]
  }

  # KMS for the EKS secrets-encryption key. CreateKey/CreateAlias/ListAliases
  # don't support resource-level restriction, so Resource has to be "*" here
  # - that's an AWS API limitation, not a choice.
  statement {
    effect = "Allow"

    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:ListAliases",
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:GetKeyPolicy",
      "kms:TagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]

    resources = ["*"]
  }

  # SSM parameter EKS publishes the recommended worker-node AMI release
  # version under - owned by AWS, not this account.
  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]

    resources = [
      "arn:${local.partition}:ssm:${var.region}::parameter/aws/service/eks/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:CreateServiceLinkedRole"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"

      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "eks-fargate.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
      ]
    }
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

resource "aws_iam_policy" "s3" {
  name   = "github-actions-s3"
  policy = data.aws_iam_policy_document.s3.json
}

resource "aws_iam_policy" "eks_support" {
  name   = "github-actions-eks-support"
  policy = data.aws_iam_policy_document.eks_support.json
}

# ------------------------------------------------------------------------------
# GitHub Actions Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_terraform" {
  name = "github-actions-terraform"

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
    s3              = aws_iam_policy.s3.arn
    eks_support     = aws_iam_policy.eks_support.arn
  }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = local.github_actions_policies

  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = each.value
}

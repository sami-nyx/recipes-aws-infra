# ==============================================================================
# EKS Cluster IAM Role
# ==============================================================================

resource "aws_iam_role" "cluster_role" {

  name = "${var.name_prefix}-eks-cluster-roe"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]

        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}


# ==============================================================================
# EKS Cluster
# ==============================================================================

locals {
  cluster_name = "${var.owner}-cluster"
}

resource "aws_eks_cluster" "this" {
  name    = local.cluster_name
  version = "1.36"
  region  = var.region

  role_arn = aws_iam_role.cluster_role.arn

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids = var.nodes_in_public ? (
      var.public_subnet_ids
    ) : (
      concat(
        var.private_subnet_ids,
        var.public_subnet_ids
      )
    )
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.eks_cluster,
  ]
}
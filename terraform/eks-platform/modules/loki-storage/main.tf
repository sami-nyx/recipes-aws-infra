# 1. Create the S3 bucket for Loki chunks
resource "aws_s3_bucket" "loki_storage" {
  bucket = "recipes-app-loki-logs-${var.environment}"
depends_on = [ module.loki_irsa_role ]
}

# 2. Block public access completely
resource "aws_s3_bucket_public_access_block" "loki_storage_block" {
  bucket                  = aws_s3_bucket.loki_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

# 3. Define the IAM Policy granting S3 access to this bucket
data "aws_iam_policy_document" "loki_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.loki_storage.arn,
      "${aws_s3_bucket.loki_storage.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "loki_s3" {
  name        = "loki-s3-policy-${var.environment}"
  description = "Policy for Grafana Loki to access S3 chunks storage"
  policy      = data.aws_iam_policy_document.loki_s3_policy.json
}

module "loki_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8.0"

  name = "loki-s3-role-${var.environment}"

  policies = {
    policy = aws_iam_policy.loki_s3.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["logging:loki-service-account"]
    }
  }
}


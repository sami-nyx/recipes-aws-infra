terraform {
  # >= 1.11 required: use_lockfile (native S3 state locking) became
  # generally available in Terraform 1.11.
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "tf-state-bucket-gh-actions-oidc-roles"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}  
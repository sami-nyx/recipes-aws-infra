terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket = "tf-state-bucket-gh-actions-oidc-roles"
    key    = "dev/terraform.tfstate"
    region = "ap-south-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}  
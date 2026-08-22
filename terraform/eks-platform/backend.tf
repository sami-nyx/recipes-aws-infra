terraform {
  required_version = "~> v1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.60.0"
    }
  }


  backend "s3" {
    bucket = "tf-state-bucket-eks-platform-recipes"
    key    = "staging/terraform.tfstate"
    region = "ap-south-1"
  }
}
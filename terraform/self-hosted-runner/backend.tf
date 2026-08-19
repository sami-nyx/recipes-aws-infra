terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket = "tf-state-bucket-self-hosted-runner-protfolio"
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
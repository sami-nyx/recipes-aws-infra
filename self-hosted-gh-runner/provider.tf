provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "recipes-self-hosted-runner"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "sami-nyx"
    }
  }
}

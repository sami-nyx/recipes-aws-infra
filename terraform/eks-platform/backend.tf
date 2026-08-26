terraform {
  # >= rather than ~> 1.15.0: the apply workflow's setup-terraform step
  # doesn't pin a version (always installs latest), so a narrow ~> 1.15.0
  # pin here breaks the moment 1.16 ships. This still requires >= 1.11 for
  # use_lockfile below, and stays open-ended like the other two stacks.
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.60.0"
    }
  }


  backend "s3" {
    bucket       = "tf-state-bucket-eks-platform-recipes"
    key          = "staging/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
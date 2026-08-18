provider "aws" {
  default_tags {
    tags = {
      Project   = "recipes-oidc-roles"
      ManagedBy = "Terraform"
      Owner     = "sami-nyx"
    }
  }
}

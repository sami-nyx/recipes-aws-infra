module "networking" {
  source      = "./modules/networking"
  vpc_cidr    = "10.0.0.0/16"
  environment = var.environment

}

module "security" {
  source      = "./modules/security"
  vpc_id      = module.networking.vpc_id
  environment = var.environment
}

module "compute" {
  source                       = "./modules/compute"
  subnet_id                    = module.networking.public_subnet_id
  security_group_id            = module.security.app_security_group_id
  instance_type                = var.instance_type
  environment                  = var.environment
  runner_instance_profile_name = module.security.runner_instance_profile_name
  aws_region                   = var.aws_region
  repo_owner                   = var.repo_owner
  repo_name                    = var.repo_name
  runner_name                  = var.runner_name
  runner_version               = var.runner_version
  docker_compose_version       = var.docker_compose_version
  docker_version               = var.docker_version
}
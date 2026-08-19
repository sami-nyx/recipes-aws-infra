variable "aws_region" {
  type        = string
  description = "The AWS region where resources will be provisioned."
}

variable "environment" {
  type        = string
  description = "The target deployment environment (e.g., test, dev, prod)."
}

variable "instance_type" {
  type        = string
  description = "The EC2 instance type to use for the self-hosted GitHub runner."
}

variable "repo_owner" {
  type        = string
  description = "The GitHub username or organization owner of the target repository."
}

variable "repo_name" {
  type        = string
  description = "The name of the GitHub repository where the runner will be registered."
}

variable "runner_version" {
  type        = string
  description = "The specific version release of the GitHub Actions runner agent."
}

variable "runner_name" {
  type        = string
  description = "The identifier name assigned to the self-hosted runner instance."
}

variable "docker_version" {
  type        = string
  description = "The target version of Docker Engine to install on the EC2 instance."
}

variable "docker_compose_version" {
  type        = string
  description = "The target version of Docker Compose to install on the EC2 instance."
}
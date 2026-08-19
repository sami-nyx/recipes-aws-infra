# variable "aws_region" {
#   type = string
# }
# variable "environment" {
#   type = string
# }
# variable "instance_type" {
#   type = string
# }
# variable "repo_owner" {
#   type = string
# }
# variable "repo_name" {
#   type = string
# }
# variable "runner_version" {
#   type = string
# }
# variable "runner_name" {
#   type = string
# }
# variable "docker_version" {
#   type = string
# }
# variable "docker_compose_version" {
#   type = string
# }
variable "aws_region" {
  type        = string
  description = "The AWS region where resources will be provisioned."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "The target deployment environment (e.g., test, dev, prod)."
  default     = "test"
}

variable "instance_type" {
  type        = string
  description = "The EC2 instance type to use for the self-hosted GitHub runner."
  default     = "t3.micro"
}

variable "repo_owner" {
  type        = string
  description = "The GitHub username or organization owner of the target repository."
  default     = "your-github-username"
}

variable "repo_name" {
  type        = string
  description = "The name of the GitHub repository where the runner will be registered."
  default     = "portfolio-recipes"
}

variable "runner_version" {
  type        = string
  description = "The specific version release of the GitHub Actions runner agent."
  default     = "2.336.0"
}

variable "runner_name" {
  type        = string
  description = "The identifier name assigned to the self-hosted runner instance."
  default     = "ec2-self-hosted-runner"
}

variable "docker_version" {
  type        = string
  description = "The target version of Docker Engine to install on the EC2 instance."
  default     = "26.0.0"
}

variable "docker_compose_version" {
  type        = string
  description = "The target version of Docker Compose to install on the EC2 instance."
  default     = "2.26.0"
}
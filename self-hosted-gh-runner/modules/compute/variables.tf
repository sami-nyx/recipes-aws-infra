variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type    = string
}

variable "environment" {
  type = string
}
variable "runner_instance_profile_name" {
  type= string
}
variable "aws_region" {
  type = string
  
}
variable "repo_owner" {
  type = string
}
variable "repo_name" {
  type = string
}
variable "runner_version" {
  type = string
}
variable "runner_name" {
  type = string
}

variable "docker_version" {
  type = string
}
variable "docker_compose_version" {
  type = string
}
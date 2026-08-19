
variable "common_tags" {
  default = {
    owner     = "terraform-eks"
    managedBy = "terraform"
    usage     = "training"
    app_name  = "app_name"
    env       = "staging"
  }
}

variable "region" {
  type = string
}

variable "vpc_cidrs" {
  description = "vpc cidrs"
  type        = string
}


variable "ha" {
  type = number

}

variable "nodes_in_public" {
  type        = bool
  default     = true
  description = "If true, nodes deploy in public subnets (saves money by avoiding NAT gateway). If false, deploys private subnets + NAT gateway."
}

variable "node_type" {

}
variable "node_counts" {

}

variable "environment" {

}

variable "principal_arn" {
  
}
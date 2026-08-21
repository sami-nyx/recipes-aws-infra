
variable "owner" {

}
variable "subnet_ids" {

}
variable "vpc_id" {

}
variable "node_type" {

}
variable "name_prefix" {

}

variable "node_counts" {
  type = object({
    min     = number
    desired = number
    max     = number
  })

  validation {
    condition     = var.node_counts.min <= var.node_counts.desired && var.node_counts.desired <= var.node_counts.max
    error_message = "Node count sizing error: Must satisfy 'min <= desired <= max'."
  }
}

variable "principal_arn" {

}
variable "bootstrap_role_arn" {

}
variable "region" {
  
}
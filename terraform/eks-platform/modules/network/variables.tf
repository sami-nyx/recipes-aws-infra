variable "vpc_cidrs" {
  description = "vpc cidrs"
  type        = string
}

variable "name_prefix" {
  type        = string
  description = "Prefix to attach to each of the names of the resources"
}


variable "ha" {
  type        = number
  description = "High Availabilty Redundancy"
  validation {
    condition     = var.ha >= 2 && var.ha <= 3
    error_message = "The ha variable must be greater or equl to 2 and less or equal to 3."
  }
}

variable "nodes_in_public" {
  type        = bool
  default     = true
  description = "If true, nodes deploy in public subnets (saves money by avoiding NAT gateway). If false, deploys private subnets + NAT gateway."
}
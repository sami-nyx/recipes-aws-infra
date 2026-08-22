variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the RDS DB subnet group"
}

variable "db_engine" {
  type        = string
  description = "The database engine to use (e.g., postgres)"
}

variable "db_engine_version" {
  type        = string
  description = "The database engine version (e.g., 18.4)"
}

variable "db_allocated_storage" {
  type        = number
  description = "The allocated storage size in GB"
}

variable "db_name" {
  type        = string
  description = "The name of the default database to create"
}

variable "db_instance_class" {
  type        = string
  description = "The instance type of the RDS database"
}

variable "db_username" {
  type        = string
  description = "Master username for the database"
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "Whether to skip the final snapshot before teardown"
}

variable "db_backup_retention_period" {
  type        = number
  description = "Number of days to retain automated RDS backups"
}

variable "db_deletion_protection" {
  type        = bool
  description = "Whether to prevent accidental deletion of the RDS instance"
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where the security group will be created"
}

variable "node_sg_id" {
  type        = string
  description = "The security group ID of the EKS worker nodes allowed to connect to RDS"
}

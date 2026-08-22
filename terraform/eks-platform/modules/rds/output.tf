output "db_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.rds_db.address
}

output "db_port" {
  description = "RDS database port"
  value       = aws_db_instance.rds_db.port
}

output "db_name" {
  description = "RDS database name"
  value       = aws_db_instance.rds_db.db_name
}

output "db_username" {
  description = "RDS master username"
  value       = aws_db_instance.rds_db.username
}

output "db_instance_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.rds_db.identifier
}

output "db_security_group_id" {
  description = "Security group attached to the RDS instance"
  value       = aws_security_group.rds_sg.id
}
output "db_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master credentials"
  value       = aws_db_instance.rds_db.master_user_secret[0].secret_arn
}
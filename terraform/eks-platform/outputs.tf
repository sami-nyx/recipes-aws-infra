output "eks_node_group_name" {
  value = module.eks_core.eks_managed_node_group
}
output "cluster_name" {
  value = module.eks_core.cluster_name
}

output "ebs_csi_irsa_role_name" {
  value = module.eks_core.ebs_csi_irsa_role_name
}

output "external_secrets_role_arn" {
  value = module.cluster_roles.external_secrets_role_arn
}
output "loki_irsa_role_arn" {
  value = module.loki_storege.loki_irsa_role_arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_core.cluster_name}"
}
output "cluster_region" {
  value = var.region
}

#rds
output "db_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.db_endpoint
}

output "db_port" {
  description = "RDS database port"
  value       = module.rds.db_port
}

output "db_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "db_username" {
  description = "RDS master username"
  value       = module.rds.db_username
}

# output "db_instance_identifier" {
#   description = "RDS instance identifier"
#   value       = module.rds.db_instance_identifier
# }

# output "db_security_group_id" {
#   description = "Security group attached to the RDS instance"
#   value       = aws_security_group.rds_sg.id
# }
output "db_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master credentials"
  value       = module.rds.db_master_user_secret_arn
}
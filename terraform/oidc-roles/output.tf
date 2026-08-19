output "created_roles_summary" {
  description = "Formatted summary of created IAM roles and their associated permissions"
  value       = <<EOT
=========================================================================================
created roles:
${module.ecr_push_role.role_name} 
  + ECR Read/Write Access 
-----------------------------------------------------------------------------------------
${module.eks_controller_role.role_name} 
  + EKS DescribeCluster Access & AmazonEKSClusterAdminPolicy Access Entry
-----------------------------------------------------------------------------------------
${module.s3_push_role.role_name} 
  + S3 Push and describe on the static web hosting bucket
=========================================================================================
EOT
}

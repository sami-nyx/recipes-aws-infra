output "s3_push_role_name" {
  value = module.ecr_push_role.name
}
output "ecr_push_role_name" {
  value = module.ecr_push_role.name
}
output "eks_runner_role_name" {
  value = module.s3_push_role.name
}
output "loki_irsa_role_arn" {
  value       = module.loki_irsa_role.arn
  description = "IAM Role ARN for Loki Service Account"
}
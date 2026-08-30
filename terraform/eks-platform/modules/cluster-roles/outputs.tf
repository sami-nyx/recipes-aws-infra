output "external_secrets_role_arn" {
  value = module.external_secrets_irsa_role.arn
}

output "cert_manager_route53_role_arn" {
  value = module.cert_manager_route53_irsa_role.arn
}

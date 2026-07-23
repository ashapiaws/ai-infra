output "acm_certificate_arn" {
  description = "ARN of the validated ACM certificate. Use this in Kubernetes Ingress/Gateway annotations to attach to the ALB."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "acm_certificate_domain" {
  description = "Primary domain name of the ACM certificate"
  value       = aws_acm_certificate.this.domain_name
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID (for creating alias records to the ALB)"
  value       = data.aws_route53_zone.this.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = data.aws_route53_zone.this.name
}

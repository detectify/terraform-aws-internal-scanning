#---------------------------------------------------------------
# Route53 DNS Records (Optional)
#---------------------------------------------------------------

# DNS validation record for ACM certificate
# Note: ACM validation requires a public Route53 zone
resource "aws_route53_record" "scan_scheduler_cert_validation" {
  for_each = var.api_enabled && var.api_domain != null ? {
    for dvo in aws_acm_certificate.scan_scheduler[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_public_zone_id
}

# DNS record pointing to the ALB
resource "aws_route53_record" "scan_scheduler" {
  count = var.api_enabled && var.api_domain != null ? 1 : 0

  zone_id = var.route53_private_zone_id
  name    = var.api_domain
  type    = "A"

  alias {
    name                   = kubernetes_ingress_v1.scan_scheduler[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = local.alb_hosted_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    kubernetes_ingress_v1.scan_scheduler
  ]
}

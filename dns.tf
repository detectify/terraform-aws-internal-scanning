#---------------------------------------------------------------
# Route53 DNS Records (Optional)
#---------------------------------------------------------------
#
# IMPORTANT: ACM Certificate Validation Behavior
# ----------------------------------------------
# ACM certificates created by this module are validated via DNS records.
# The validation records are only created when BOTH conditions are met:
#   - create_acm_certificate = true
#   - create_route53_record = true
#
# If you manage DNS externally (create_route53_record = false):
#   1. The ACM certificate will be created but remain in PENDING_VALIDATION state
#   2. You must manually create the DNS validation records in your DNS provider
#   3. Use the certificate's domain_validation_options output to get the required records
#   4. Once validation records are created, ACM will automatically validate the certificate
#
# For external DNS users, consider using an existing validated certificate
# by setting create_acm_certificate = false and providing acm_certificate_arn.
#---------------------------------------------------------------

# DNS validation record for ACM certificate
# Note: ACM validation requires a public Route53 zone
resource "aws_route53_record" "scan_scheduler_cert_validation" {
  for_each = var.create_acm_certificate && var.create_route53_record ? {
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
  # Use acm_validation_zone_id if provided, otherwise fall back to route53_zone_id
  zone_id = var.acm_validation_zone_id != null ? var.acm_validation_zone_id : var.route53_zone_id
}

# DNS record pointing to the ALB
resource "aws_route53_record" "scan_scheduler" {
  count = var.create_ingress && var.create_route53_record ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.scanner_url
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.scan_scheduler_status[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = local.alb_hosted_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    data.kubernetes_ingress_v1.scan_scheduler_status[0],
    time_sleep.wait_for_alb[0]
  ]
}

# DNS validation record for Prometheus certificate (if enabled)
# Note: ACM validation requires a public Route53 zone
resource "aws_route53_record" "prometheus_cert_validation" {
  for_each = var.enable_prometheus && var.create_route53_record ? {
    for dvo in aws_acm_certificate.prometheus[0].domain_validation_options : dvo.domain_name => {
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
  # Use acm_validation_zone_id if provided, otherwise fall back to route53_zone_id
  zone_id = var.acm_validation_zone_id != null ? var.acm_validation_zone_id : var.route53_zone_id
}

# DNS record for Prometheus (if enabled)
resource "aws_route53_record" "prometheus" {
  count = var.enable_prometheus && var.create_route53_record ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.prometheus_url
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.prometheus_status[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = local.alb_hosted_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    data.kubernetes_ingress_v1.prometheus_status[0]
  ]
}

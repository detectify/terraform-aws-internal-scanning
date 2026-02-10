#---------------------------------------------------------------
# ACM Certificate for Scan Scheduler
#---------------------------------------------------------------

resource "aws_acm_certificate" "scan_scheduler" {
  count = var.create_acm_certificate ? 1 : 0

  domain_name       = var.scanner_url
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "scanner-${var.environment}"
  }
}

# Certificate validation (requires DNS records to be created externally or via Route53)
resource "aws_acm_certificate_validation" "scan_scheduler" {
  count = var.create_acm_certificate && var.create_route53_record ? 1 : 0

  certificate_arn         = aws_acm_certificate.scan_scheduler[0].arn
  validation_record_fqdns = [for record in aws_route53_record.scan_scheduler_cert_validation : record.fqdn]
}

#---------------------------------------------------------------
# Internal ALB Ingress for Scan Scheduler
#---------------------------------------------------------------

resource "kubernetes_ingress_v1" "scan_scheduler" {
  count = var.create_ingress ? 1 : 0

  metadata {
    name      = "scan-scheduler"
    namespace = "scanner" # Created by Helm

    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"               = "internal"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/health"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
      "alb.ingress.kubernetes.io/certificate-arn"      = var.create_acm_certificate ? (var.create_route53_record ? aws_acm_certificate_validation.scan_scheduler[0].certificate_arn : aws_acm_certificate.scan_scheduler[0].arn) : var.acm_certificate_arn
      "alb.ingress.kubernetes.io/subnets"              = join(",", var.private_subnet_ids)
      "alb.ingress.kubernetes.io/tags"                 = "Environment=${var.environment},Service=${var.cluster_name_prefix}"
      "alb.ingress.kubernetes.io/inbound-cidrs"        = join(",", var.alb_inbound_cidrs)
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.scanner_url

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "scan-scheduler" # Created by Helm
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    module.eks,                          # Wait for EKS cluster and access entries
    helm_release.aws_load_balancer_controller,
    helm_release.scanner,                # Wait for Helm to create namespace and service
    time_sleep.wait_for_alb_cleanup,     # On destroy: wait for ALB cleanup before removing controller
  ]
}

#---------------------------------------------------------------
# Load balancer setup for scanner API
#---------------------------------------------------------------

resource "kubernetes_manifest" "alb_params" {
  count = var.api_enabled ? 1 : 0

  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "IngressClassParams"

    metadata = {
      name = "alb"
    }

    spec = {
      scheme = "internal"

      subnets = {
        ids = var.private_subnet_ids
      }

      certificateARNs = var.api_domain != null ? [aws_acm_certificate_validation.scan_scheduler[0].certificate_arn] : []

      tags = [{
        key   = "Name"
        value = var.name
      }]
    }
  }

  depends_on = [
    module.eks,
  ]
}

resource "kubernetes_ingress_class_v1" "auto_mode_alb" {
  count = var.api_enabled ? 1 : 0

  metadata {
    name = "alb"
  }

  spec {
    controller = "eks.amazonaws.com/alb"

    parameters {
      api_group = "eks.amazonaws.com"
      kind      = "IngressClassParams"
      name      = kubernetes_manifest.alb_params[0].manifest.metadata.name
    }
  }
}

resource "kubernetes_ingress_v1" "scan_scheduler" {
  count = var.api_enabled ? 1 : 0

  wait_for_load_balancer = true

  metadata {
    name      = "scan-scheduler"
    namespace = "scanner"

    annotations = merge(
      {
        "alb.ingress.kubernetes.io/target-type"          = "ip"
        "alb.ingress.kubernetes.io/healthcheck-path"     = "/health"
        "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
        "alb.ingress.kubernetes.io/tags"                 = "Name=${var.name}"
        "alb.ingress.kubernetes.io/inbound-cidrs"        = join(",", var.api_allowed_cidrs)
      },
      var.api_domain != null ? {
        "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
        "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
        "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate_validation.scan_scheduler[0].certificate_arn
        } : {
        "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
      }
    )
  }

  spec {
    ingress_class_name = kubernetes_ingress_class_v1.auto_mode_alb[0].metadata[0].name

    rule {
      host = var.api_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "scan-scheduler"
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
    module.eks,
    kubernetes_ingress_class_v1.auto_mode_alb,
    helm_release.scanner,
  ]
}

# Look up the ALB in AWS using the tags we defined in IngressClassParams
data "aws_lb" "auto_mode_alb" {
  count = var.api_enabled ? 1 : 0

  tags = {
    "Name" = var.name
  }

  depends_on = [
    kubernetes_ingress_v1.scan_scheduler
  ]
}

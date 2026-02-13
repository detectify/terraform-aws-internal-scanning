#---------------------------------------------------------------
# Prometheus for Scanner Metrics (Optional)
#---------------------------------------------------------------

check "prometheus_url_required" {
  assert {
    condition     = !var.enable_prometheus || var.prometheus_url != null
    error_message = "prometheus_url is required when enable_prometheus is true. Either set prometheus_url or set enable_prometheus = false."
  }
}

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enable_prometheus ? 1 : 0

  metadata {
    name = "monitoring"
  }

  depends_on = [
    module.eks,
  ]
}

resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  version    = "27.52.0"

  values = [
    yamlencode({
      server = {
        persistentVolume = {
          enabled = false # Disable for EKS Auto Mode compatibility
        }
        retention = "7d"
      }

      alertmanager = {
        enabled = false # Disable alerting
      }

      pushgateway = {
        enabled = false
      }

      "prometheus-node-exporter" = {
        enabled = false # Don't need node metrics
      }

      "kube-state-metrics" = {
        enabled = false # Don't need cluster-wide metrics
      }

      serverFiles = {
        "prometheus.yml" = {
          scrape_configs = [
            {
              job_name = "scanner-services"
              kubernetes_sd_configs = [
                {
                  role = "service"
                  namespaces = {
                    names = ["scanner"]
                  }
                }
              ]
              relabel_configs = [
                # Only scrape services with prometheus.io/scrape: "true" annotation
                {
                  source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_scrape"]
                  action        = "keep"
                  regex         = "true"
                },
                # Use the prometheus.io/path annotation for metrics path
                {
                  source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_path"]
                  action        = "replace"
                  target_label  = "__metrics_path__"
                  regex         = "(.+)"
                },
                # Use the prometheus.io/port annotation for port
                {
                  source_labels = ["__address__", "__meta_kubernetes_service_annotation_prometheus_io_port"]
                  action        = "replace"
                  regex         = "([^:]+)(?::\\d+)?;(\\d+)"
                  replacement   = "$1:$2"
                  target_label  = "__address__"
                }
              ]
            }
          ]
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.monitoring[0]]
}

#---------------------------------------------------------------
# ACM Certificate for Prometheus
#---------------------------------------------------------------

resource "aws_acm_certificate" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  domain_name       = var.prometheus_url
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "prometheus-${var.environment}"
  }
}

# Certificate validation (requires DNS records)
resource "aws_acm_certificate_validation" "prometheus" {
  count = var.enable_prometheus && var.create_route53_record ? 1 : 0

  certificate_arn         = aws_acm_certificate.prometheus[0].arn
  validation_record_fqdns = [for record in aws_route53_record.prometheus_cert_validation : record.fqdn]
}

#---------------------------------------------------------------
# ALB Ingress for Prometheus
#---------------------------------------------------------------

resource "kubernetes_ingress_v1" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  wait_for_load_balancer = true

  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"               = "internal"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/-/healthy"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
      "alb.ingress.kubernetes.io/certificate-arn"      = var.create_route53_record ? aws_acm_certificate_validation.prometheus[0].certificate_arn : aws_acm_certificate.prometheus[0].arn
      "alb.ingress.kubernetes.io/subnets"              = join(",", var.private_subnet_ids)
      "alb.ingress.kubernetes.io/tags"                 = "Environment=${var.environment},Service=prometheus"
      "alb.ingress.kubernetes.io/inbound-cidrs"        = join(",", var.alb_inbound_cidrs)
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.prometheus_url

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "prometheus-server" # Created by Helm
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    module.eks, # Wait for EKS cluster and access entries
    helm_release.aws_load_balancer_controller,
    helm_release.prometheus,
  ]
}

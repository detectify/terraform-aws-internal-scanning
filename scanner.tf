locals {
  # Build full image registry path from server and path
  # e.g., "registry.detectify.com" + "internal-scanning" -> "registry.detectify.com/internal-scanning"
  image_registry = "${var.registry_server}/${var.image_registry_path}"
}

resource "helm_release" "scanner" {
  name      = "scanner"
  namespace = "scanner"

  # Use local path if provided, otherwise use repository
  chart      = var.helm_chart_path != null ? var.helm_chart_path : "internal-scanning-agent"
  repository = var.helm_chart_path != null ? null : var.helm_chart_repository
  version    = var.helm_chart_path != null ? null : var.helm_chart_version

  create_namespace = true

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      # Registry URL with full path where images are stored
      registry = {
        url              = local.image_registry
        imagePullSecrets = [{ name = "detectify-registry" }]
        server           = var.registry_server
        username         = var.registry_username
        password         = var.registry_password
      }

      images = {
        scanScheduler = {
          repository = "scan-scheduler"
          tag        = var.internal_scanning_version
          pullPolicy = "Always"
        }
        scanManager = {
          repository = "scan-manager"
          tag        = var.internal_scanning_version
          pullPolicy = "Always"
        }
        chromeController = {
          repository = "chrome-controller"
          tag        = var.internal_scanning_version
          pullPolicy = "Always"
        }
        scanWorker = {
          repository = "scan-worker"
          tag        = var.internal_scanning_version
          pullPolicy = "Always"
        }
        chromeContainer = {
          repository = "chrome-container"
          tag        = var.internal_scanning_version
          pullPolicy = "Always"
        }
        redis = {
          repository = "redis"
          tag        = "7-alpine"
          pullPolicy = "IfNotPresent"
        }
      }

      namespace = {
        name = "scanner"
      }

      replicaCount = {
        scanScheduler    = var.scan_scheduler_replicas
        scanManager      = var.scan_manager_replicas
        chromeController = var.chrome_controller_replicas
        redis            = var.redis_replicas
      }

      resources = {
        scanScheduler    = var.scan_scheduler_resources
        scanManager      = var.scan_manager_resources
        chromeController = var.chrome_controller_resources
        redis            = var.redis_resources
      }

      autoscaling = {
        enabled       = var.enable_autoscaling
        scanScheduler = var.scan_scheduler_autoscaling
        scanManager   = var.scan_manager_autoscaling
      }

      config = merge(
        {
          port               = "3000"
          redisUrl           = "redis://redis:6379"
          licenseKey         = var.license_key
          licenseServerUrl   = var.license_server_url
          connectorServerUrl = var.connector_server_url
          connectorApiKey    = var.connector_api_key
          scannerNamespace   = "scanner"
          imagePullPolicy    = "Always"
          imagePullSecret    = "detectify-registry"
          chromeContainerTag = var.internal_scanning_version
          enableMetrics      = tostring(var.enable_prometheus)

          # Logging configuration
          logFormat = var.log_format

          # Poll intervals
          scheduledScansPollIntervalSeconds = tostring(var.scheduled_scans_poll_interval_seconds)
          completedScansPollIntervalSeconds = tostring(var.completed_scans_poll_interval_seconds)
        },
        var.max_scan_duration_seconds != null ? {
          maxScanDurationSeconds = tostring(var.max_scan_duration_seconds)
        } : {}
      )

      redis = {
        storage = {
          size = var.redis_storage_size
        }
      }

      probes = {
        liveness = {
          initialDelaySeconds = 30
          periodSeconds       = 10
        }
        readiness = {
          initialDelaySeconds = 5
          periodSeconds       = 5
        }
      }
    })
  ]

  depends_on = [
    module.eks,
  ]
}

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
  wait_for_load_balancer = true

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
    module.eks, # Wait for EKS cluster and access entries
    helm_release.aws_load_balancer_controller,
    helm_release.scanner, # Wait for Helm to create namespace and service
  ]
}

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
    time_sleep.wait_for_cluster
  ]
}

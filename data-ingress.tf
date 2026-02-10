#---------------------------------------------------------------
# Data Sources for Ingress Status
#---------------------------------------------------------------
# These data sources wait for the ALB to be provisioned before
# creating DNS records

# Read the scanner ingress status after ALB is provisioned
data "kubernetes_ingress_v1" "scan_scheduler_status" {
  count = var.create_ingress ? 1 : 0

  metadata {
    name      = "scan-scheduler"
    namespace = "scanner"
  }

  depends_on = [
    kubernetes_ingress_v1.scan_scheduler,
    time_sleep.wait_for_alb
  ]
}

# Read the Prometheus ingress status after ALB is provisioned (if enabled)
data "kubernetes_ingress_v1" "prometheus_status" {
  count = var.enable_prometheus ? 1 : 0

  metadata {
    name      = "prometheus"
    namespace = "monitoring"
  }

  depends_on = [
    kubernetes_ingress_v1.prometheus,
    time_sleep.wait_for_alb
  ]
}

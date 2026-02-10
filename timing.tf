#---------------------------------------------------------------
# Timing Resources to Handle Dependencies
#---------------------------------------------------------------
# These resources ensure proper sequencing of operations

# Wait for EKS cluster to be fully ready before deploying Helm charts
# Increased wait time to ensure IAM access entries and permissions propagate
# With enable_cluster_creator_admin_permissions = false, we need extra time
# for the access entries to become active before Kubernetes/Helm providers can authenticate
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    module.eks
  ]

  create_duration = var.cluster_ready_timeout
}

# Wait for ingress to be fully provisioned with ALB before creating DNS records
resource "time_sleep" "wait_for_alb" {
  count = var.create_ingress ? 1 : 0

  depends_on = [
    kubernetes_ingress_v1.scan_scheduler[0]
  ]

  create_duration = var.alb_provisioning_timeout
}

# On destroy, wait for ALB controller to clean up AWS resources (ALBs, target groups)
# after ingresses are deleted but before the controller itself is removed.
resource "time_sleep" "wait_for_alb_cleanup" {
  count = var.create_ingress ? 1 : 0

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]

  destroy_duration = var.alb_provisioning_timeout
}

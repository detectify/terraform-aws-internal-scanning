#---------------------------------------------------------------
# AWS Load Balancer Controller
#---------------------------------------------------------------

# IAM role for AWS Load Balancer Controller using IRSA
module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.environment}-alb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

}

# Deploy AWS Load Balancer Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"

  namespace        = "kube-system"
  create_namespace = false

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      clusterName = local.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.load_balancer_controller_irsa_role.iam_role_arn
        }
      }
      region = var.aws_region
      vpcId  = var.vpc_id
    })
  ]

  depends_on = [
    module.eks,
    time_sleep.wait_for_cluster
  ]
}

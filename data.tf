#---------------------------------------------------------------
# Data Sources
#---------------------------------------------------------------

# Current AWS account information
data "aws_caller_identity" "current" {}

# EKS cluster auth for Kubernetes provider
data "aws_eks_cluster_auth" "cluster" {
  name = local.cluster_name

  depends_on = [module.eks]
}

# Get ALB hosted zone ID for the region (for Route53 alias records)
data "aws_elb_hosted_zone_id" "main" {}

locals {
  alb_hosted_zone_id = data.aws_elb_hosted_zone_id.main.id
  account_id         = data.aws_caller_identity.current.account_id
}

# Complete Deployment Example
#
# This example shows a full-featured deployment with:
# - Route53 DNS integration
# - Autoscaling enabled
# - Custom resource configurations
# - Prometheus monitoring

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "detectify-internal-scanning"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.internal_scanner.cluster_name
}

provider "kubernetes" {
  host                   = module.internal_scanner.cluster_endpoint
  cluster_ca_certificate = base64decode(module.internal_scanner.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.internal_scanner.cluster_endpoint
    cluster_ca_certificate = base64decode(module.internal_scanner.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

module "internal_scanner" {
  source = "detectify/detectify-internal-scanning/aws"
  # version = "~> 1.0"  # Uncomment when using from registry

  # Core Configuration
  environment         = var.environment
  aws_region          = var.aws_region
  cluster_name_prefix = "internal-scanning"

  # Network Configuration
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  alb_inbound_cidrs  = var.alb_inbound_cidrs

  # Scanner Endpoint with DNS
  scanner_url           = "scanner.${var.environment}.${var.domain_name}"
  create_route53_record = true
  route53_zone_id       = var.route53_zone_id

  # ACM Certificate
  create_acm_certificate = true
  acm_validation_zone_id = var.acm_validation_zone_id # Public zone for validation

  # Image Configuration
  internal_scanning_version = var.scanner_version

  # License Configuration (provided by Detectify)
  license_key       = var.license_key
  connector_api_key = var.connector_api_key

  # Registry Authentication (provided by Detectify)
  registry_username = var.registry_username
  registry_password = var.registry_password

  # Autoscaling Configuration
  enable_autoscaling = true

  scan_scheduler_autoscaling = {
    min_replicas                         = 2
    max_replicas                         = 10
    target_cpu_utilization_percentage    = 70
    target_memory_utilization_percentage = null
  }

  scan_manager_autoscaling = {
    min_replicas                         = 1
    max_replicas                         = 20
    target_cpu_utilization_percentage    = 80
    target_memory_utilization_percentage = null
  }

  # Resource Configuration
  scan_scheduler_resources = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }

  scan_manager_resources = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }

  # Redis Configuration
  redis_storage_size = "16Gi"

  # Observability
  enable_cloudwatch_observability = true
  enable_prometheus               = true
  prometheus_url                  = "prometheus.${var.environment}.${var.domain_name}"

  # IAM - Grant admin access to specific roles
  cluster_admin_role_arns = var.cluster_admin_role_arns
}

# Outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.internal_scanner.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.internal_scanner.cluster_endpoint
}

output "scanner_url" {
  description = "Scanner API endpoint URL"
  value       = module.internal_scanner.scanner_url
}

output "prometheus_url" {
  description = "Prometheus endpoint URL"
  value       = module.internal_scanner.prometheus_url
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = module.internal_scanner.kubeconfig_command
}

output "kms_key_arn" {
  description = "KMS key ARN for secrets encryption"
  value       = module.internal_scanner.kms_key_arn
}

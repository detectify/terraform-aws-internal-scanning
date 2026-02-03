# Basic Deployment Example
#
# This example shows the minimum configuration required to deploy
# Detectify Internal Scanning on AWS EKS.

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
  environment = var.environment
  aws_region  = var.aws_region

  # Network Configuration
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  alb_inbound_cidrs  = var.alb_inbound_cidrs

  # Scanner Endpoint
  scanner_url = var.scanner_url

  # License Configuration (provided by Detectify)
  license_key       = var.license_key
  connector_api_key = var.connector_api_key

  # Registry Authentication (provided by Detectify)
  registry_username = var.registry_username
  registry_password = var.registry_password
}

output "scanner_url" {
  description = "Scanner API endpoint URL"
  value       = module.internal_scanner.scanner_url
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = module.internal_scanner.kubeconfig_command
}

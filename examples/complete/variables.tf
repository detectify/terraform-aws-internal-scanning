variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes (minimum 2)"
  type        = list(string)
}

variable "alb_inbound_cidrs" {
  description = "CIDR blocks allowed to access the internal ALB"
  type        = list(string)
}

variable "domain_name" {
  description = "Base domain name for scanner endpoints"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
}

variable "acm_validation_zone_id" {
  description = "Route53 public zone ID for ACM certificate validation"
  type        = string
}

variable "scanner_version" {
  description = "Scanner image version tag"
  type        = string
  default     = "latest"
}

variable "cluster_admin_role_arns" {
  description = "IAM role ARNs to grant EKS cluster admin access"
  type        = list(string)
  default     = []
}

# Sensitive variables - provide via terraform.tfvars or environment variables
variable "license_key" {
  description = "Detectify license key"
  type        = string
  sensitive   = true
}

variable "connector_api_key" {
  description = "Detectify connector API key"
  type        = string
  sensitive   = true
}

variable "registry_username" {
  description = "Detectify registry username"
  type        = string
  sensitive   = true
}

variable "registry_password" {
  description = "Detectify registry password"
  type        = string
  sensitive   = true
}

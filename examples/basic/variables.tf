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

variable "scanner_url" {
  description = "Domain name for the scanner endpoint"
  type        = string
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

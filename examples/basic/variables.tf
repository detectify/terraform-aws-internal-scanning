variable "name" {
  description = "Name of the deployment. Resources deployed to AWS will have this name (sometimes just as a prefix)."
  type        = string
  default     = "detectify-scanner"
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes (minimum 2)"
  type        = list(string)
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

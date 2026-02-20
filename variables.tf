#---------------------------------------------------------------
# Helm Chart Configuration
#---------------------------------------------------------------

variable "helm_chart_repository" {
  description = "Helm chart repository URL. Set to null to use helm_chart_path instead."
  type        = string
  default     = "https://detectify.github.io/helm-charts"
}

variable "helm_chart_version" {
  description = "Helm chart version. Only used when helm_chart_repository is set."
  type        = string
  default     = null # Uses latest if not specified
}

variable "helm_chart_path" {
  description = "Local path to Helm chart. Takes precedence over helm_chart_repository when set."
  type        = string
  default     = null
}

#---------------------------------------------------------------
# Core Configuration
#---------------------------------------------------------------

variable "environment" {
  description = "Environment name (e.g., development, staging, production)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "Environment must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS Region where resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name_prefix" {
  description = "Prefix for EKS cluster name (will be combined with environment)"
  type        = string
  default     = "internal-scanning"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.35"
}

#---------------------------------------------------------------
# Network Configuration
#---------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes and internal ALB"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }
}

variable "cluster_endpoint_public_access" {
  description = <<-EOT
    Enable public access to the EKS cluster API endpoint. When true, the Kubernetes
    API is reachable over the internet (subject to cluster_endpoint_public_access_cidrs).

    Use this when users need kubectl/deployment access without VPN connectivity.
    Private access remains enabled regardless of this setting.

    IMPORTANT: Even with public access, all requests still require valid IAM
    authentication. Restrict access further using cluster_endpoint_public_access_cidrs.
  EOT
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = <<-EOT
    CIDR blocks allowed to access the EKS cluster API endpoint over the public internet.
    Only applies when cluster_endpoint_public_access = true.

    IMPORTANT: When enabling public access, restrict this to specific IPs instead of
    using the default 0.0.0.0/0. AWS requires at least one CIDR in this list.

    Example: ["203.0.113.0/24", "198.51.100.10/32"]
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "At least one CIDR block is required. AWS EKS does not accept an empty list."
  }
}

variable "cluster_security_group_additional_rules" {
  description = <<-EOT
    Additional security group rules for the EKS cluster API endpoint.

    Required when Terraform runs from a network that doesn't have direct access to the
    private subnets (e.g., local machine via VPN, CI/CD pipeline in another VPC, bastion host).
    Add an ingress rule for port 443 from the CIDR where Terraform is running.

    Example:
      cluster_security_group_additional_rules = {
        terraform_access = {
          description = "Allow Terraform access from VPN"
          type        = "ingress"
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["10.0.0.0/8"]  # Your VPN/CI network CIDR
        }
      }
  EOT
  type        = map(any)
  default     = {}
}

variable "alb_inbound_cidrs" {
  description = <<-EOT
    CIDR blocks allowed to access the scanner API endpoint via the internal ALB.

    Typically includes:
    - Your VPC CIDR (required - scanner components communicate via the ALB)
    - VPN/corporate network CIDRs (for administrative access and debugging)

    Example: ["10.0.0.0/16", "172.16.0.0/12"]
  EOT
  type        = list(string)

  validation {
    condition     = length(var.alb_inbound_cidrs) > 0
    error_message = "At least one CIDR block must be specified for ALB access."
  }
}

#---------------------------------------------------------------
# Scanner Endpoint Configuration
#---------------------------------------------------------------
# The scanner endpoint is the internal API that receives scan requests. It runs
# behind an internal ALB and is only accessible from within your network.
#
# DNS Setup:
# - route53_zone_id: Can be a private hosted zone (for internal DNS resolution)
# - acm_validation_zone_id: Must be a PUBLIC hosted zone (ACM requires public DNS for validation)
#
# If your DNS zone is private-only, you'll need to either:
# 1. Use a separate public zone for ACM validation (set acm_validation_zone_id)
# 2. Bring your own certificate (set create_acm_certificate = false, provide acm_certificate_arn)
#---------------------------------------------------------------

variable "scanner_url" {
  description = <<-EOT
    Hostname for the scanner API endpoint (e.g., scanner.example.com).

    This endpoint is used to:
    - Start scans (from CI/CD pipelines or manually)
    - Get scan status
    - Get logs (for support requests to Detectify)

    The endpoint is exposed via an internal ALB and is only accessible from
    networks specified in alb_inbound_cidrs.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.scanner_url))
    error_message = "Scanner URL must be a valid domain name without protocol (e.g., scanner.example.com)."
  }
}

variable "create_route53_record" {
  description = "Create Route53 DNS A record pointing scanner_url to the ALB. Set to false if managing DNS externally."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = <<-EOT
    Route53 hosted zone ID for the scanner DNS A record.
    Required when create_route53_record = true.

    Can be a private hosted zone if the scanner is only accessed internally.
    The zone must contain the domain used in scanner_url.
  EOT
  type        = string
  default     = null
}

variable "acm_validation_zone_id" {
  description = <<-EOT
    Route53 hosted zone ID for ACM certificate DNS validation.
    Defaults to route53_zone_id if not specified.

    IMPORTANT: Must be a PUBLIC hosted zone - ACM certificate validation requires
    publicly resolvable DNS records. If route53_zone_id is a private zone, you must
    provide a separate public zone here, or use create_acm_certificate = false with
    your own certificate.
  EOT
  type        = string
  default     = null
}

variable "create_acm_certificate" {
  description = "Create and validate an ACM certificate for the scanner endpoint. Set to false to use an existing certificate."
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ARN of an existing ACM certificate. Required when create_acm_certificate = false."
  type        = string
  default     = null
}

#---------------------------------------------------------------
# Container Image Configuration
#---------------------------------------------------------------

variable "registry_server" {
  description = "Docker registry server hostname for authentication and image pulls (e.g., registry.detectify.com)"
  type        = string
  default     = "registry.detectify.com"
}

variable "image_registry_path" {
  description = "Path within the registry where scanner images are stored. Combined with registry_server to form full image URLs (e.g., registry_server/image_registry_path/scan-scheduler)."
  type        = string
  default     = "internal-scanning"
}

variable "internal_scanning_version" {
  description = "Version tag for all scanner images (scan-scheduler, scan-manager, scan-worker, chrome-controller, chrome-container). Defaults to 'latest' to ensure customers always have the newest security tests. For production stability, consider pinning to a specific version (e.g., 'v1.0.0')."
  type        = string
  default     = "stable"
}

variable "registry_username" {
  description = "Docker registry username for image pulls"
  type        = string
  sensitive   = true
}

variable "registry_password" {
  description = "Docker registry password for image pulls"
  type        = string
  sensitive   = true
}

#---------------------------------------------------------------
# License Configuration
#---------------------------------------------------------------

variable "license_key" {
  description = "Scanner license key"
  type        = string
  sensitive   = true
}

variable "license_server_url" {
  description = "License validation server URL. Defaults to production license server."
  type        = string
  default     = "https://license.detectify.com"
}

variable "connector_server_url" {
  description = "Connector service URL for scanner communication. Defaults to production connector."
  type        = string
  default     = "https://connector.detectify.com"
}

variable "connector_api_key" {
  description = "Connector API key for authentication with Detectify services"
  type        = string
  sensitive   = true
}

#---------------------------------------------------------------
# Application Configuration
#---------------------------------------------------------------

variable "scan_scheduler_replicas" {
  description = "Number of Scan Scheduler replicas"
  type        = number
  default     = 1
}

variable "scan_manager_replicas" {
  description = "Number of Scan Manager replicas"
  type        = number
  default     = 1
}

variable "chrome_controller_replicas" {
  description = "Number of Chrome Controller replicas"
  type        = number
  default     = 1
}

variable "redis_storage_size" {
  description = "Redis persistent volume size"
  type        = string
  default     = "8Gi"
}

variable "redis_storage_class" {
  description = "Kubernetes StorageClass for the Redis PVC. Defaults to ebs-gp3 (EKS Auto Mode with EBS CSI driver)."
  type        = string
  default     = "ebs-gp3"
}

variable "deploy_redis" {
  description = "Deploy in-cluster Redis. Set to false when using managed Redis (e.g., ElastiCache, Memorystore) and override redis_url."
  type        = bool
  default     = true
}

variable "redis_url" {
  description = "Redis connection URL. Override when using external/managed Redis. Include credentials and use rediss:// for TLS (e.g., rediss://user:pass@my-redis.example.com:6379)."
  type        = string
  default     = "redis://redis:6379"
}

variable "enable_autoscaling" {
  description = "Enable Horizontal Pod Autoscaler (HPA) for scan-scheduler and scan-manager"
  type        = bool
  default     = false
}

variable "scan_scheduler_autoscaling" {
  description = "Autoscaling configuration for Scan Scheduler"
  type = object({
    min_replicas                         = number
    max_replicas                         = number
    target_cpu_utilization_percentage    = number
    target_memory_utilization_percentage = optional(number)
  })
  default = {
    min_replicas                         = 1
    max_replicas                         = 10
    target_cpu_utilization_percentage    = 70
    target_memory_utilization_percentage = null
  }
}

variable "scan_manager_autoscaling" {
  description = "Autoscaling configuration for Scan Manager"
  type = object({
    min_replicas                         = number
    max_replicas                         = number
    target_cpu_utilization_percentage    = number
    target_memory_utilization_percentage = optional(number)
  })
  default = {
    min_replicas                         = 1
    max_replicas                         = 20
    target_cpu_utilization_percentage    = 80
    target_memory_utilization_percentage = null
  }
}

variable "scan_scheduler_resources" {
  description = "Resource requests and limits for Scan Scheduler"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "scan_manager_resources" {
  description = "Resource requests and limits for Scan Manager"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "chrome_controller_resources" {
  description = "Resource requests and limits for Chrome Controller"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "redis_resources" {
  description = "Resource requests and limits for Redis"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

#---------------------------------------------------------------
# Scan Configuration
#---------------------------------------------------------------

variable "max_scan_duration_seconds" {
  description = "Maximum duration for a single scan in seconds. If not specified, defaults to 172800 (2 days). Only set this if you need to override the default."
  type        = number
  default     = null
}

variable "scheduled_scans_poll_interval_seconds" {
  description = "Interval in seconds for polling the connector for scheduled scans. Minimum: 60 seconds. Lower values increase API calls to Detectify."
  type        = number
  default     = 600 # 10 minutes

  validation {
    condition     = var.scheduled_scans_poll_interval_seconds >= 60
    error_message = "Scheduled scans poll interval must be at least 60 seconds to prevent flooding."
  }
}

variable "completed_scans_poll_interval_seconds" {
  description = "Interval in seconds for checking if running scans have completed. Minimum: 10 seconds. Lower values provide faster result reporting but increase Redis load."
  type        = number
  default     = 60 # 1 minute

  validation {
    condition     = var.completed_scans_poll_interval_seconds >= 10
    error_message = "Completed scans poll interval must be at least 10 seconds to prevent flooding."
  }
}

#---------------------------------------------------------------
# Logging Configuration
#---------------------------------------------------------------

variable "log_format" {
  description = "Log output format. Use 'json' for machine-readable logs (recommended for log aggregation systems like ELK, Splunk, CloudWatch). Use 'text' for human-readable console output."
  type        = string
  default     = "json"

  validation {
    condition     = contains(["json", "text"], var.log_format)
    error_message = "Log format must be either 'json' or 'text'."
  }
}

#---------------------------------------------------------------
# Observability Configuration
#---------------------------------------------------------------

variable "enable_cloudwatch_observability" {
  description = "Enable Amazon CloudWatch Observability addon for logs and metrics"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring stack with pushgateway. When true, deploys Prometheus for metrics scraping and pushgateway for ephemeral job metrics. When false, no metrics infrastructure is deployed."
  type        = bool
  default     = false
}

variable "prometheus_url" {
  description = "Full URL for Prometheus endpoint (required if enable_prometheus is true)"
  type        = string
  default     = null
}

#---------------------------------------------------------------
# Encryption Configuration
#---------------------------------------------------------------

variable "kms_key_arn" {
  description = "ARN of an existing KMS key to use for secrets encryption. If not provided, a new KMS key will be created."
  type        = string
  default     = null
}

variable "kms_key_deletion_window" {
  description = "Number of days before KMS key is deleted after destruction (7-30 days)"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

#---------------------------------------------------------------
# IAM Configuration
#---------------------------------------------------------------

variable "enable_cluster_creator_admin_permissions" {
  description = "Whether to grant the cluster creator admin permissions. Set to true to allow the creator to manage the cluster, false to manage all access manually via cluster_admin_role_arns."
  type        = bool
  default     = true
}

variable "cluster_admin_role_arns" {
  description = "IAM role ARNs to grant cluster admin access (for AWS Console/CLI access)"
  type        = list(string)
  default     = []
}


# Detectify Internal Scanning - AWS Terraform Module

[![Terraform Registry](https://img.shields.io/badge/Terraform-Registry-blue.svg)](https://registry.terraform.io/modules/detectify/detectify-internal-scanning/aws)
[![License](https://img.shields.io/badge/License-BSL%201.1-blue.svg)](LICENSE)

This Terraform module deploys [Detectify's Internal Scanning](https://detectify.com) solution on AWS using Amazon EKS with Auto Mode.

## Features

- **EKS Auto Mode** - Simplified Kubernetes management with automatic node provisioning
- **Automatic TLS** - ACM certificate provisioning with DNS validation
- **Internal ALB** - Secure internal Application Load Balancer
- **Horizontal Pod Autoscaling** - Automatic scaling based on CPU/memory utilization
- **KMS Encryption** - Secrets encrypted at rest using AWS KMS
- **CloudWatch Integration** - Optional observability with CloudWatch Logs and Metrics
- **Prometheus Monitoring** - Optional Prometheus stack with Pushgateway

## Prerequisites

- **Terraform** >= 1.5.0
- **AWS CLI** configured with credentials (`aws configure` or environment variables)
- **AWS IAM permissions** - The IAM principal running Terraform needs permissions to create:
  - EKS clusters and node groups
  - IAM roles and policies
  - KMS keys
  - Security groups
  - Application Load Balancers
  - Route53 records (if using DNS integration)
  - ACM certificates (if using automatic TLS)
- **VPC** with at least 2 private subnets (in different availability zones)
- **Detectify License** - Contact [Detectify](https://detectify.com) to obtain:
  - License key
  - Registry credentials
  - Connector API key

## Quick Start

```hcl
provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project     = "detectify-internal-scanning"
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

# EKS authentication - retrieves token for Kubernetes/Helm providers
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
  source  = "detectify/detectify-internal-scanning/aws"
  version = "~> 1.0"

  # Core Configuration
  environment = "production"
  aws_region  = "eu-west-1"

  # Network Configuration
  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  alb_inbound_cidrs  = ["10.0.0.0/8"]

  # Scanner Endpoint
  scanner_url           = "scanner.internal.example.com"
  create_route53_record = true
  route53_zone_id       = "Z1234567890ABC"

  # License Configuration (provided by Detectify)
  license_key       = var.license_key
  connector_api_key = var.connector_api_key

  # Registry Authentication (provided by Detectify)
  registry_username = var.registry_username
  registry_password = var.registry_password
}
```

## Examples

- [Basic Deployment](examples/basic/) - Minimal configuration
- [Complete Deployment](examples/complete/) - Full-featured with autoscaling, monitoring, and DNS

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.52 |
| kubernetes | >= 2.13.1 |
| helm | >= 2.9.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.52 |
| kubernetes | >= 2.13.1 |
| helm | >= 2.9.0 |

## Inputs

### Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `environment` | Environment name (e.g., development, staging, production) | `string` |
| `vpc_id` | VPC ID where EKS cluster will be deployed | `string` |
| `private_subnet_ids` | Private subnet IDs for EKS nodes (minimum 2 for HA) | `list(string)` |
| `scanner_url` | Domain name for the scanner endpoint (e.g., scanner.example.com) | `string` |
| `alb_inbound_cidrs` | CIDR blocks allowed to access the internal ALB | `list(string)` |
| `license_key` | Scanner license key (provided by Detectify) | `string` |
| `connector_api_key` | Connector API key (provided by Detectify) | `string` |

### Conditionally Required Inputs

| Name | Description | Required When |
|------|-------------|---------------|
| `route53_zone_id` | Route53 hosted zone ID for DNS records | `create_route53_record = true` |
| `prometheus_url` | Full URL for Prometheus endpoint (e.g., prometheus.example.com) | `enable_prometheus = true` |

### Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `aws_region` | AWS Region for deployment | `string` | `"us-east-1"` |
| `cluster_name_prefix` | Prefix for EKS cluster name | `string` | `"internal-scanning"` |
| `cluster_version` | Kubernetes version | `string` | `"1.34"` |
| `internal_scanning_version` | Version tag for scanner images | `string` | `"latest"` |
| `registry_server` | Docker registry server hostname | `string` | `"registry.detectify.com"` |
| `image_registry_path` | Path within registry for scanner images | `string` | `"internal-scanning"` |
| `license_server_url` | License server URL | `string` | `"https://license.detectify.com"` |
| `connector_server_url` | Connector service URL | `string` | `"https://connector.detectify.com"` |
| `enable_autoscaling` | Enable HPA for scan-scheduler and scan-manager | `bool` | `false` |
| `enable_cloudwatch_observability` | Enable CloudWatch observability addon | `bool` | `true` |
| `enable_prometheus` | Enable Prometheus monitoring stack | `bool` | `true` |
| `max_scan_duration_seconds` | Maximum duration for a single scan in seconds | `number` | `null` (defaults to 172800 / 2 days) |
| `create_route53_record` | Create Route53 DNS record | `bool` | `false` |
| `create_acm_certificate` | Create and validate ACM certificate | `bool` | `true` |
| `kms_key_arn` | Existing KMS key ARN for secrets encryption (creates new if not provided) | `string` | `null` |

### Registry Configuration

| Name | Description | Type |
|------|-------------|------|
| `registry_username` | Docker registry username | `string` |
| `registry_password` | Docker registry password | `string` |

> **Note:** The full image registry URL is automatically constructed as `${registry_server}/${image_registry_path}` (e.g., `registry.detectify.com/internal-scanning`).

### Scaling Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `scan_scheduler_replicas` | Number of Scan Scheduler replicas | `number` | `2` |
| `scan_manager_replicas` | Number of Scan Manager replicas | `number` | `1` |
| `chrome_controller_replicas` | Number of Chrome Controller replicas | `number` | `1` |
| `redis_replicas` | Number of Redis replicas | `number` | `1` |
| `redis_storage_size` | Redis persistent volume size | `string` | `"8Gi"` |

### Autoscaling Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `scan_scheduler_autoscaling` | Autoscaling config for Scan Scheduler | `object` | See below |
| `scan_manager_autoscaling` | Autoscaling config for Scan Manager | `object` | See below |

Default autoscaling configuration:
```hcl
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
```

### IAM Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_cluster_creator_admin_permissions` | Grant cluster creator admin permissions | `bool` | `true` |
| `cluster_admin_role_arns` | IAM role ARNs to grant cluster admin access | `list(string)` | `[]` |

### Timing Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `cluster_ready_timeout` | Time to wait for EKS cluster to be fully ready before deploying workloads | `string` | `"120s"` |
| `alb_provisioning_timeout` | Time to wait for ALB to be fully provisioned before creating DNS records | `string` | `"120s"` |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | EKS cluster ID |
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | EKS cluster API endpoint |
| `scanner_url` | Scanner API endpoint URL |
| `alb_dns_name` | DNS name of the internal ALB |
| `kubeconfig_command` | Command to configure kubectl |
| `kms_key_arn` | ARN of the KMS key used for secrets encryption |
| `acm_certificate_arn` | ARN of the ACM certificate |
| `acm_certificate_domain_validation_options` | DNS validation records for external DNS users |

## Architecture

```
                                 +------------------+
                                 |   Route53 DNS    |
                                 +--------+---------+
                                          |
                                 +--------v---------+
                                 |  Internal ALB    |
                                 |   (HTTPS/443)    |
                                 +--------+---------+
                                          |
                                 +--------v---------+
                                 | Scan Scheduler   |  <-- API Entry Point
                                 |   (HPA: 2-10)    |
                                 +--------+---------+
                                          |
                                 +--------v---------+
                                 |      Redis       |  <-- Job Queue
                                 |   (Persistent)   |
                                 +--------+---------+
                                          |
                                 +--------v---------+
                                 |  Scan Manager    |  <-- Creates scan workers
                                 |   (HPA: 1-20)    |
                                 +--------+---------+
                                    |           |
                     +--------------+           +--------------+
                     |                                         |
            +--------v--------+                    +-----------v-----------+
            |   Scan Worker   |                    |   Chrome Controller   |
            | (ephemeral pods)|<------------------>|                       |
            +-----------------+                    +-----------+-----------+
                                                               |
                                                   +-----------v-----------+
                                                   |   Chrome Container    |
                                                   |  (browser instances)  |
                                                   +-----------------------+
```

**Component Responsibilities:**
- **Scan Scheduler**: API entry point, validates licenses, queues scan jobs to Redis
- **Redis**: Persistent job queue for scan requests
- **Scan Manager**: Polls Redis, creates ephemeral scan-worker pods, reports results to Connector
- **Scan Worker**: Ephemeral pods that execute security scans
- **Chrome Controller**: Manages browser instances for JavaScript-heavy scanning
- **Chrome Container**: Headless Chrome instances used by scan workers

## Security

- **Network Isolation**: Cluster runs in private subnets with no public endpoint
- **Encryption at Rest**: Kubernetes secrets encrypted with KMS
- **TLS Everywhere**: ALB terminates TLS with ACM certificate
- **RBAC**: Fine-grained Kubernetes RBAC for service accounts
- **IAM Roles for Service Accounts (IRSA)**: Pods use scoped IAM roles

## Scanner Endpoint

The scanner exposes an internal API endpoint via an Application Load Balancer (ALB). This endpoint is used to:
- **Start scans** from CI/CD pipelines or manually
- **Get scan status** to monitor progress
- **Get logs** for support requests to Detectify

**Network Access:** Configure `alb_inbound_cidrs` to allow access from:
- Your VPC CIDR (for CI/CD pipelines running in your network)
- VPN/corporate networks (for manual access and support debugging)

## DNS and Certificate Configuration

The scanner endpoint requires a hostname (`scanner_url`) and TLS certificate. There are two hosted zones to consider:

| Zone | Purpose | Can be Private? |
|------|---------|-----------------|
| `route53_zone_id` | DNS A record for scanner_url | Yes |
| `acm_validation_zone_id` | ACM certificate validation | **No - must be public** |

### Using Route53 (Recommended)

**If you have a public hosted zone:**
```hcl
scanner_url           = "scanner.example.com"
create_route53_record = true
route53_zone_id       = "Z1234567890ABC"  # Public zone works for both DNS and ACM
```

**If you have separate private and public zones:**
```hcl
scanner_url            = "scanner.internal.example.com"
create_route53_record  = true
route53_zone_id        = "Z_PRIVATE_ZONE"  # Private zone for DNS A record
acm_validation_zone_id = "Z_PUBLIC_ZONE"   # Public zone for ACM validation
```

### Using External DNS

If you manage DNS outside of Route53 (`create_route53_record = false`):

1. **Option A: Bring your own certificate**
   ```hcl
   create_acm_certificate = false
   acm_certificate_arn    = "arn:aws:acm:region:account:certificate/xxx"
   ```
   Then create your DNS record pointing to the ALB (available in outputs).

2. **Option B: Manual certificate validation**
   - Set `create_acm_certificate = true`
   - The certificate will be created in `PENDING_VALIDATION` state
   - Retrieve validation records from the `acm_certificate_domain_validation_options` output
   - Create the CNAME records in your DNS provider
   - ACM will automatically validate once records are detected

## Autoscaling

The module supports Horizontal Pod Autoscaling (HPA) for scan-scheduler and scan-manager:

| Component | Default Min | Default Max | Scale Trigger |
|-----------|-------------|-------------|---------------|
| Scan Scheduler | 2 | 10 | 70% CPU |
| Scan Manager | 1 | 20 | 80% CPU |

**Scaling Behavior:**
- **Scale Up**: Fast (100% increase every 30s or +2 pods, whichever is larger)
- **Scale Down**: Gradual (50% decrease every 60s with 5-minute stabilization)

Node autoscaling is handled automatically by EKS Auto Mode.

## Upgrading

To upgrade the scanner components:

```hcl
module "internal_scanner" {
  # ...
  internal_scanning_version = "v1.2.0"  # New version
}
```

Then apply:
```bash
terraform apply
```

## Troubleshooting

### Connect to the cluster

```bash
# Get kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check pods
kubectl get pods -n scanner

# Check logs
kubectl logs -n scanner deployment/scan-scheduler
kubectl logs -n scanner deployment/scan-manager
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Terraform hangs or times out connecting to EKS | Terraform needs network access to the EKS API endpoint (port 443). If running from a VPN, CI/CD pipeline, or bastion host outside the VPC, add `cluster_security_group_additional_rules` with an ingress rule for your network CIDR. See variable description for example. |
| Pods stuck in `ImagePullBackOff` | Verify registry credentials are correct |
| ALB not provisioning | Check subnet tags and IAM permissions |
| Certificate validation failing | Ensure ACM validation DNS zone is public |
| `route53_zone_id is required` | Set `route53_zone_id` when `create_route53_record = true` |
| `prometheus_url is required` | Set `prometheus_url` when `enable_prometheus = true`, or disable with `enable_prometheus = false` |
| `At least one CIDR block must be specified` | Provide at least one CIDR in `alb_inbound_cidrs` (e.g., your VPC CIDR) |

## License

Business Source License 1.1 (BSL 1.1) - See [LICENSE](LICENSE) for details.

**Key terms:**
- Production use requires a valid Detectify Internal Scanning license
- Non-production use (testing, development) is permitted
- Converts to Apache 2.0 after 4 years

## Support

- **Documentation**: [Detectify Docs](https://docs.detectify.com)
- **Issues**: [GitHub Issues](https://github.com/detectify/terraform-aws-internal-scanning/issues)
- **Contact**: [Detectify Support](https://support.detectify.com)

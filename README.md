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

## Quick Start

```hcl
provider "aws" {
  region = "eu-west-1"
}

# Retrieves cluster auth token for Kubernetes and Helm providers
data "aws_eks_cluster_auth" "cluster" {
  name = module.internal_scanner.cluster_name

  depends_on = [
    # Explicit dependency must be set for data resources or it'll be
    # evaluated as soon as the cluster name is known rather than waiting
    # until the cluster is deployed.
    # https://developer.hashicorp.com/terraform/language/data-sources#dependencies
    module.internal_scanner.cluster_name,
  ]
}

provider "kubernetes" {
  host                   = module.internal_scanner.cluster_endpoint
  cluster_ca_certificate = base64decode(module.internal_scanner.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes = {
    host                   = module.internal_scanner.cluster_endpoint
    cluster_ca_certificate = base64decode(module.internal_scanner.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

module "internal_scanner" {
  source  = "detectify/internal-scanning/aws"
  version = "~> 1.0"

  # Core Configuration
  name = "detectify-scanner"

  # Network Configuration
  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.52 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.13.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.0.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 20.0 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.scan_scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.scan_scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_iam_role.cloudwatch_observability_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cloudwatch_observability_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.eks_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.eks_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_route53_record.scan_scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.scan_scheduler_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [helm_release.scanner](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_ingress_class_v1.auto_mode_alb](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_class_v1) | resource |
| [kubernetes_ingress_v1.scan_scheduler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_manifest.alb_params](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_storage_class_v1.ebs_gp3](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_elb_hosted_zone_id.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_hosted_zone_id) | data source |
| [aws_lb.auto_mode_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_allowed_cidrs"></a> [api\_allowed\_cidrs](#input\_api\_allowed\_cidrs) | CIDR blocks allowed to access the scanner API endpoint via an internal ALB.<br/><br/>Example: ["10.0.0.0/16", "172.16.0.0/12"]<br/><br/>`api_enabled` must be `true` for this to have any effect. | `list(string)` | `[]` | no |
| <a name="input_api_domain"></a> [api\_domain](#input\_api\_domain) | Hostname for the scanner API endpoint (e.g., scanner.example.com).<br/><br/>This endpoint is used to:<br/>- Start scans (from CI/CD pipelines or manually)<br/>- Get scan status<br/>- Get logs (for support requests to Detectify)<br/><br/>The endpoint is exposed via an internal ALB and is only accessible from<br/>networks specified in api\_allowed\_cidrs. | `string` | `null` | no |
| <a name="input_api_enabled"></a> [api\_enabled](#input\_api\_enabled) | Enables the Internal Scanner REST API that maybe be used to start scans, fetch results etc.<br/><br/>Enabling this creates an internal load balancer to expose the API. When `api_domain` is also<br/>provided, DNS records and a TLS certificate are set up as well. | `bool` | `false` | no |
| <a name="input_chrome_controller_replicas"></a> [chrome\_controller\_replicas](#input\_chrome\_controller\_replicas) | Number of Chrome Controller replicas | `number` | `1` | no |
| <a name="input_chrome_controller_resources"></a> [chrome\_controller\_resources](#input\_chrome\_controller\_resources) | Resource requests and limits for Chrome Controller | <pre>object({<br/>    requests = object({<br/>      cpu    = string<br/>      memory = string<br/>    })<br/>    limits = object({<br/>      cpu    = string<br/>      memory = string<br/>    })<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "1000m",<br/>    "memory": "2Gi"<br/>  },<br/>  "requests": {<br/>    "cpu": "200m",<br/>    "memory": "512Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_admin_role_arns"></a> [cluster\_admin\_role\_arns](#input\_cluster\_admin\_role\_arns) | IAM role ARNs to grant cluster admin access (for AWS Console/CLI access) | `list(string)` | `[]` | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | Enable public access to the EKS cluster API endpoint. When true, the Kubernetes<br/>API is reachable over the internet (subject to cluster\_endpoint\_public\_access\_cidrs).<br/><br/>Use this when users need kubectl/deployment access without direct connection via e.g. VPN<br/>or bastion hosts.<br/><br/>Private access remains enabled regardless of this setting.<br/><br/>IMPORTANT: Even with public access, all requests still require valid IAM<br/>authentication. Restrict access further using cluster\_endpoint\_public\_access\_cidrs. | `bool` | `true` | no |
| <a name="input_cluster_endpoint_public_access_cidrs"></a> [cluster\_endpoint\_public\_access\_cidrs](#input\_cluster\_endpoint\_public\_access\_cidrs) | CIDR blocks allowed to access the EKS cluster API endpoint over the public internet.<br/>Only applies when cluster\_endpoint\_public\_access = true.<br/><br/>IMPORTANT: When enabling public access, restrict this to specific IPs instead of<br/>using the default 0.0.0.0/0. AWS requires at least one CIDR in this list.<br/><br/>Example: ["203.0.113.0/24", "198.51.100.10/32"] | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_cluster_security_group_additional_rules"></a> [cluster\_security\_group\_additional\_rules](#input\_cluster\_security\_group\_additional\_rules) | Additional security group rules for the EKS cluster API endpoint.<br/><br/>Required when Terraform runs from a network that doesn't have direct access to the<br/>private subnets (e.g., local machine via VPN, CI/CD pipeline in another VPC, bastion host).<br/>Add an ingress rule for port 443 from the CIDR where Terraform is running.<br/><br/>Example:<br/>  cluster\_security\_group\_additional\_rules = {<br/>    terraform\_access = {<br/>      description = "Allow Terraform access from VPN"<br/>      type        = "ingress"<br/>      from\_port   = 443<br/>      to\_port     = 443<br/>      protocol    = "tcp"<br/>      cidr\_blocks = ["10.0.0.0/8"]  # Your VPN/CI network CIDR<br/>    }<br/>  } | `map(any)` | `{}` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes version for EKS cluster | `string` | `"1.35"` | no |
| <a name="input_completed_scans_poll_interval_seconds"></a> [completed\_scans\_poll\_interval\_seconds](#input\_completed\_scans\_poll\_interval\_seconds) | Interval in seconds for checking if running scans have completed. Minimum: 10 seconds. Lower values provide faster result reporting but increase Redis load. | `number` | `60` | no |
| <a name="input_connector_api_key"></a> [connector\_api\_key](#input\_connector\_api\_key) | Connector API key for authentication with Detectify services | `string` | n/a | yes |
| <a name="input_connector_server_url"></a> [connector\_server\_url](#input\_connector\_server\_url) | Connector service URL for scanner communication. Defaults to production connector. | `string` | `"https://connector.detectify.com"` | no |
| <a name="input_deploy_redis"></a> [deploy\_redis](#input\_deploy\_redis) | Deploy in-cluster Redis. Set to false when using managed Redis (e.g., ElastiCache, Memorystore) and override redis\_url. | `bool` | `true` | no |
| <a name="input_enable_autoscaling"></a> [enable\_autoscaling](#input\_enable\_autoscaling) | Enable Horizontal Pod Autoscaler (HPA) for scan-scheduler and scan-manager | `bool` | `false` | no |
| <a name="input_enable_cloudwatch_observability"></a> [enable\_cloudwatch\_observability](#input\_enable\_cloudwatch\_observability) | Enable Amazon CloudWatch Observability addon for logs and metrics | `bool` | `true` | no |
| <a name="input_enable_cluster_creator_admin_permissions"></a> [enable\_cluster\_creator\_admin\_permissions](#input\_enable\_cluster\_creator\_admin\_permissions) | Whether to grant the cluster creator admin permissions. Set to true to allow the creator to manage the cluster, false to manage all access manually via cluster\_admin\_role\_arns. | `bool` | `true` | no |
| <a name="input_helm_chart_path"></a> [helm\_chart\_path](#input\_helm\_chart\_path) | Local path to Helm chart. Takes precedence over helm\_chart\_repository when set. | `string` | `null` | no |
| <a name="input_helm_chart_repository"></a> [helm\_chart\_repository](#input\_helm\_chart\_repository) | Helm chart repository URL. Set to null to use helm\_chart\_path instead. | `string` | `"https://detectify.github.io/helm-charts"` | no |
| <a name="input_helm_chart_version"></a> [helm\_chart\_version](#input\_helm\_chart\_version) | Helm chart version. Only used when helm\_chart\_repository is set. | `string` | `null` | no |
| <a name="input_image_registry_path"></a> [image\_registry\_path](#input\_image\_registry\_path) | Path within the registry where scanner images are stored. Combined with registry\_server to form full image URLs (e.g., registry\_server/image\_registry\_path/scan-scheduler). | `string` | `"internal-scanning"` | no |
| <a name="input_internal_scanning_version"></a> [internal\_scanning\_version](#input\_internal\_scanning\_version) | Version tag for all scanner images (scan-scheduler, scan-manager, scan-worker, chrome-controller, chrome-container). Defaults to 'latest' to ensure customers always have the newest security tests. For production stability, consider pinning to a specific version (e.g., 'v1.0.0'). | `string` | `"stable"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of an existing KMS key to use for secrets encryption. If not provided, a new KMS key will be created. | `string` | `null` | no |
| <a name="input_kms_key_deletion_window"></a> [kms\_key\_deletion\_window](#input\_kms\_key\_deletion\_window) | Number of days before KMS key is deleted after destruction (7-30 days) | `number` | `30` | no |
| <a name="input_license_key"></a> [license\_key](#input\_license\_key) | Scanner license key | `string` | n/a | yes |
| <a name="input_license_server_url"></a> [license\_server\_url](#input\_license\_server\_url) | License validation server URL. Defaults to production license server. | `string` | `"https://license.detectify.com"` | no |
| <a name="input_log_format"></a> [log\_format](#input\_log\_format) | Log output format. Use 'json' for machine-readable logs (recommended for log aggregation systems like ELK, Splunk, CloudWatch). Use 'text' for human-readable console output. | `string` | `"json"` | no |
| <a name="input_max_scan_duration_seconds"></a> [max\_scan\_duration\_seconds](#input\_max\_scan\_duration\_seconds) | Maximum duration for a single scan in seconds. If not specified, defaults to 172800 (2 days). Only set this if you need to override the default. | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Unique name for this deployment (e.g. production-internal-scanning) | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for EKS nodes and internal ALB | `list(string)` | n/a | yes |
| <a name="input_redis_resources"></a> [redis\_resources](#input\_redis\_resources) | Resource requests and limits for Redis | <pre>object({<br/>    requests = object({<br/>      cpu    = string<br/>      memory = string<br/>    })<br/>    limits = object({<br/>      cpu    = string<br/>      memory = string<br/>    })<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "500m",<br/>    "memory": "512Mi"<br/>  },<br/>  "requests": {<br/>    "cpu": "100m",<br/>    "memory": "128Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_redis_storage_class"></a> [redis\_storage\_class](#input\_redis\_storage\_class) | Kubernetes StorageClass for the Redis PVC. Defaults to ebs-gp3 (EKS Auto Mode with EBS CSI driver). | `string` | `"ebs-gp3"` | no |
| <a name="input_redis_storage_size"></a> [redis\_storage\_size](#input\_redis\_storage\_size) | Redis persistent volume size | `string` | `"8Gi"` | no |
| <a name="input_redis_url"></a> [redis\_url](#input\_redis\_url) | Redis connection URL. Override when using external/managed Redis. Include credentials and use rediss:// for TLS (e.g., rediss://user:pass@my-redis.example.com:6379). | `string` | `"redis://redis:6379"` | no |
| <a name="input_registry_password"></a> [registry\_password](#input\_registry\_password) | Docker registry password for image pulls | `string` | n/a | yes |
| <a name="input_registry_server"></a> [registry\_server](#input\_registry\_server) | Docker registry server hostname for authentication and image pulls (e.g., registry.detectify.com) | `string` | `"registry.detectify.com"` | no |
| <a name="input_registry_username"></a> [registry\_username](#input\_registry\_username) | Docker registry username for image pulls | `string` | n/a | yes |
| <a name="input_route53_private_zone_id"></a> [route53\_private\_zone\_id](#input\_route53\_private\_zone\_id) | Route53 hosted zone ID for DNS A records (scanner API).<br/>Required when api\_domain is set.<br/><br/>Can be a private hosted zone if the endpoint is only accessed internally.<br/>The zone must contain the domain used in api\_domain. | `string` | `null` | no |
| <a name="input_route53_public_zone_id"></a> [route53\_public\_zone\_id](#input\_route53\_public\_zone\_id) | Route53 public hosted zone ID for ACM certificate DNS validation.<br/>Required when api\_domain is set.<br/><br/>IMPORTANT: Must be a PUBLIC hosted zone - ACM certificate validation requires<br/>publicly resolvable DNS records. | `string` | `null` | no |
| <a name="input_scan_manager_autoscaling"></a> [scan\_manager\_autoscaling](#input\_scan\_manager\_autoscaling) | Autoscaling configuration for Scan Manager | <pre>object({<br/>    min_replicas                         = number<br/>    max_replicas                         = number<br/>    target_cpu_utilization_percentage    = number<br/>    target_memory_utilization_percentage = optional(number)<br/>  })</pre> | <pre>{<br/>  "max_replicas": 20,<br/>  "min_replicas": 1,<br/>  "target_cpu_utilization_percentage": 80,<br/>  "target_memory_utilization_percentage": null<br/>}</pre> | no |
| <a name="input_scan_manager_replicas"></a> [scan\_manager\_replicas](#input\_scan\_manager\_replicas) | Number of Scan Manager replicas | `number` | `1` | no |
| <a name="input_scan_manager_resources"></a> [scan\_manager\_resources](#input\_scan\_manager\_resources) | Resource requests and limits for Scan Manager | <pre>object({<br/>    requests = object({<br/>      cpu    = string<br/>      memory = string<br/>    })<br/>    limits = object({<br/>      cpu    = string<br/>      memory = string<br/>    })<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "1000m",<br/>    "memory": "1Gi"<br/>  },<br/>  "requests": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_scan_scheduler_autoscaling"></a> [scan\_scheduler\_autoscaling](#input\_scan\_scheduler\_autoscaling) | Autoscaling configuration for Scan Scheduler | <pre>object({<br/>    min_replicas                         = number<br/>    max_replicas                         = number<br/>    target_cpu_utilization_percentage    = number<br/>    target_memory_utilization_percentage = optional(number)<br/>  })</pre> | <pre>{<br/>  "max_replicas": 10,<br/>  "min_replicas": 1,<br/>  "target_cpu_utilization_percentage": 70,<br/>  "target_memory_utilization_percentage": null<br/>}</pre> | no |
| <a name="input_scan_scheduler_replicas"></a> [scan\_scheduler\_replicas](#input\_scan\_scheduler\_replicas) | Number of Scan Scheduler replicas | `number` | `1` | no |
| <a name="input_scan_scheduler_resources"></a> [scan\_scheduler\_resources](#input\_scan\_scheduler\_resources) | Resource requests and limits for Scan Scheduler | <pre>object({<br/>    requests = object({<br/>      cpu    = string<br/>      memory = string<br/>    })<br/>    limits = object({<br/>      cpu    = string<br/>      memory = string<br/>    })<br/>  })</pre> | <pre>{<br/>  "limits": {<br/>    "cpu": "1000m",<br/>    "memory": "1Gi"<br/>  },<br/>  "requests": {<br/>    "cpu": "200m",<br/>    "memory": "256Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_scheduled_scans_poll_interval_seconds"></a> [scheduled\_scans\_poll\_interval\_seconds](#input\_scheduled\_scans\_poll\_interval\_seconds) | Interval in seconds for polling the connector for scheduled scans. Minimum: 60 seconds. Lower values increase API calls to Detectify. | `number` | `600` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where EKS cluster will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | ARN of the ACM certificate for scan scheduler |
| <a name="output_acm_certificate_domain_validation_options"></a> [acm\_certificate\_domain\_validation\_options](#output\_acm\_certificate\_domain\_validation\_options) | Domain validation options for ACM certificate. Use these to create DNS validation records when managing DNS externally (create\_route53\_records = false). |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | The AWS ARN of the Application Load Balancer. |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the ALB created for scan scheduler |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Route53 zone ID of the ALB (for DNS record creation) |
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | Scanner API endpoint URL |
| <a name="output_cloudwatch_observability_role_arn"></a> [cloudwatch\_observability\_role\_arn](#output\_cloudwatch\_observability\_role\_arn) | IAM role ARN for CloudWatch Observability addon |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data for cluster authentication |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS cluster API endpoint |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | EKS cluster ID |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | The URL on the EKS cluster OIDC Issuer |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group ID attached to the EKS cluster |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key used for EKS secrets encryption |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | ID of the KMS key used for EKS secrets encryption (only if created by module) |
| <a name="output_kubeconfig_command"></a> [kubeconfig\_command](#output\_kubeconfig\_command) | Command to update kubeconfig for kubectl access |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC Provider for EKS |
| <a name="output_scanner_namespace"></a> [scanner\_namespace](#output\_scanner\_namespace) | Kubernetes namespace where scanner is deployed |
<!-- END_TF_DOCS -->

## Architecture

```text
                     +-----------------+
                     |   Route53 DNS   | <-- Optional
                     +--------+--------+
                              |
                     +--------v--------+
                     |  Internal ALB   | <-- Optional
                     +--------+--------+
                              |
                     +--------v--------+
                     | Scan Scheduler  |  <-- API Entry Point
                     +--------+--------+
                              |
                     +--------v--------+
                     |      Redis      |  <-- Job Queue
                     +--------+--------+
                              |
                     +--------v--------+
                     |  Scan Manager   |  <-- Creates scan workers
                     +--------+--------+
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

- **Scan Scheduler**: Communication with Detectify, API entry point, validates licenses, queues scan jobs to Redis
- **Redis**: Persistent job queue for scan requests
- **Scan Manager**: Polls Redis, creates ephemeral scan-worker pods, reports results to Connector
- **Scan Worker**: Ephemeral pods that execute security scans
- **Chrome Controller**: Manages browser instances for JavaScript-heavy scanning
- **Chrome Container**: Ephemeral Chrome instances used by scan workers

## Scanner API Endpoint

The scanner may expose an internal API endpoint via an Application Load Balancer (ALB). This endpoint is used to:

- **Start scans** from CI/CD pipelines or manually
- **Get scan status** to monitor progress
- **Get logs** for support requests to Detectify

**Network Access:** Configure `api_allowed_cidrs` to allow access from:

- Your VPC CIDR (for CI/CD pipelines running in your network)
- VPN/corporate networks (for manual access and support debugging)

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
| Terraform hangs or times out connecting to EKS | Terraform needs network access to the EKS API endpoint (port 443). **Option 1 (no VPN):** Set `cluster_endpoint_public_access = true` and restrict `cluster_endpoint_public_access_cidrs` to your IP. **Option 2 (VPN/peering):** Add `cluster_security_group_additional_rules` with an ingress rule for your network CIDR. See variable descriptions for examples. |
| Pods stuck in `ImagePullBackOff` | Verify registry credentials are correct |
| Certificate validation failing | Ensure ACM validation DNS zone is public |

## License

Business Source License 1.1 (BSL 1.1) - See [LICENSE](LICENSE) for details.

## Support

- **Documentation**: [Detectify Docs](https://docs.detectify.com)
- **Contact**: [Detectify Support](https://support.detectify.com)

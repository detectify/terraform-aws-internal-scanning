# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.7] - 2026-02-17

### Added
- Redis persistence with PVC, `storageClass` variable (defaults to `ebs-gp3`), and `deploy_redis` toggle
- `ebs-gp3` StorageClass resource (EBS CSI driver, gp3 volumes, `WaitForFirstConsumer` binding)
- `redis_url` variable to support external/managed Redis (e.g., ElastiCache)
- `Recreate` deployment strategy for Redis when persistence is enabled (prevents RWO PVC deadlock)
- `wait-for-redis` init containers on scan-scheduler and scan-manager
- PriorityClass for redis and scan-scheduler to protect critical components under resource pressure
- Lifecycle precondition: `redis_url` must be overridden when `deploy_redis` is false
- `cluster_primary_security_group_id` output

### Changed
- Bump coredns addon from v1.13.1-eksbuild.1 to v1.13.2-eksbuild.1
- Bump vpc-cni addon from v1.21.1-eksbuild.1 to v1.21.1-eksbuild.3

## [1.0.6] - 2026-02-13

### Fixed

- Fix autoscaling configuration not being applied to Helm chart — Terraform snake_case variable keys (`min_replicas`, `max_replicas`, `target_cpu_utilization_percentage`, `target_memory_utilization_percentage`) were passed directly to the Helm release, but the chart expects camelCase (`minReplicas`, `maxReplicas`, `targetCPUUtilizationPercentage`, `targetMemoryUtilizationPercentage`). This caused the chart to silently fall back to its built-in defaults, ignoring user-provided autoscaling settings.

## [1.0.5] - 2026-02-13

### Changed

- Default image version from `latest` to `stable`
- Upgrade AWS Load Balancer Controller Helm chart from 1.8.1 to 1.17.1
- Upgrade Prometheus Helm chart from 27.49.0 to 27.52.0

### Fixed

- Apply/destroy now works in a single action without sleeps

### Removed

- `var.create_ingress` — ingress is now always created
- `var.cluster_ready_timeout` and `var.alb_provisioning_timeout` — no longer needed
- `data.aws_eks_cluster_auth` from module — users must configure this in their root module with an explicit `depends_on` (see updated examples)

## [1.0.4] - 2026-02-10

### Fixed
- Add ALB cleanup delay on destroy to prevent the ALB controller from being removed before it finishes cleaning up AWS resources (ALBs, target groups) for ingresses

## [1.0.3] - 2026-02-10

### Fixed
- Fix `depends_on` references in ingress data sources and DNS records to use resource references instead of indexed instances (`[0]`), which failed on initial deployment when conditional resources did not yet exist
- Add `time_sleep.wait_for_alb` dependency to Prometheus ingress status data source to ensure ALB is provisioned before querying

## [1.0.2] - 2026-02-10

### Fixed
- Add `depends_on` to cluster outputs (`cluster_name`, `cluster_endpoint`, `cluster_certificate_authority_data`) to avoid race condition with the Helm provider on initial deployment

## [1.0.1] - 2026-02-10

### Fixed
- Use published Helm chart name `internal-scanning-agent` from repository instead of incorrect `scanner`

## [1.0.0] - 2026-02-03

### Added
- Initial release of Detectify Internal Scanning Terraform Module
- EKS Auto Mode support for simplified Kubernetes management
- Automatic TLS certificate provisioning with ACM
- Internal Application Load Balancer configuration
- Horizontal Pod Autoscaling (HPA) for scan-scheduler and scan-manager
- KMS encryption for Kubernetes secrets at rest
- CloudWatch Observability integration
- Prometheus monitoring stack with Pushgateway
- Comprehensive documentation and examples

### Components
- scan-scheduler: API entry point, license validation, job queuing
- scan-manager: Job orchestration, scan-worker pod management
- scan-worker: Ephemeral pods for security scanning
- chrome-controller: Browser instance management
- Redis: Persistent job queue

### Infrastructure
- AWS EKS with Auto Mode
- AWS ALB (internal)
- AWS ACM for TLS
- AWS KMS for encryption
- AWS Route53 (optional DNS)
- AWS CloudWatch (optional observability)

[Unreleased]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.7...HEAD
[1.0.7]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/detectify/terraform-aws-internal-scanning/releases/tag/v1.0.0

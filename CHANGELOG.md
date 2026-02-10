# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/detectify/terraform-aws-internal-scanning/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/detectify/terraform-aws-internal-scanning/releases/tag/v1.0.0

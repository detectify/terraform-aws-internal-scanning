# Complete Deployment Example

This example demonstrates a full-featured deployment with all options enabled:

- Route53 DNS integration
- ACM certificate with DNS validation
- Horizontal Pod Autoscaling
- Custom resource limits
- Prometheus monitoring
- CloudWatch observability
- IAM role access

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- VPC with at least 2 private subnets
- Route53 hosted zone (private for records, public for ACM validation)
- Detectify license credentials

## Usage

1. Create `terraform.tfvars`:

   ```hcl
   environment        = "production"
   aws_region         = "eu-west-1"
   vpc_id             = "vpc-xxxxx"
   private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
   alb_inbound_cidrs  = ["10.0.0.0/8"]

   domain_name            = "example.com"
   route53_zone_id        = "Z1234567890ABC"  # Private zone
   acm_validation_zone_id = "Z0987654321XYZ"  # Public zone

   scanner_version = "v1.0.0"

   cluster_admin_role_arns = [
     "arn:aws:iam::123456789012:role/AdminRole"
   ]

   # Credentials provided by Detectify
   license_key       = "your-license-key"
   connector_api_key = "your-connector-key"
   registry_username = "your-username"
   registry_password = "your-password"
   ```

2. Initialize and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. Configure kubectl:

   ```bash
   # Use the output command
   aws eks update-kubeconfig --region eu-west-1 --name production-internal-scanning
   ```

4. Verify pods are running:

   ```bash
   kubectl get pods -A
   ```

## Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | EKS API endpoint |
| `scanner_url` | Scanner API URL |
| `prometheus_url` | Prometheus URL |
| `kubeconfig_command` | kubectl configuration command |
| `kms_key_arn` | KMS key for secrets encryption |

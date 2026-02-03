# Basic Deployment Example

This example demonstrates the minimum configuration required to deploy Detectify Internal Scanning.

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- VPC with at least 2 private subnets
- Detectify license credentials

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   ```hcl
   environment        = "production"
   aws_region         = "eu-west-1"
   vpc_id             = "vpc-xxxxx"
   private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
   alb_inbound_cidrs  = ["10.0.0.0/8"]
   scanner_url        = "scanner.internal.example.com"

   # Credentials provided by Detectify
   license_key       = "your-license-key"
   connector_api_key = "your-connector-key"
   registry_username = "your-username"
   registry_password = "your-password"
   ```

3. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. Configure kubectl:
   ```bash
   # Use the output command
   aws eks update-kubeconfig --region eu-west-1 --name production-internal-scanning
   ```

## Inputs

| Name | Description | Required |
|------|-------------|----------|
| `environment` | Environment name | Yes |
| `vpc_id` | VPC ID | Yes |
| `private_subnet_ids` | Private subnet IDs | Yes |
| `alb_inbound_cidrs` | Allowed CIDR blocks | Yes |
| `scanner_url` | Scanner domain name | Yes |
| `license_key` | Detectify license key | Yes |
| `connector_api_key` | Connector API key | Yes |
| `registry_username` | Registry username | Yes |
| `registry_password` | Registry password | Yes |

## Outputs

| Name | Description |
|------|-------------|
| `scanner_url` | Scanner API endpoint URL |
| `kubeconfig_command` | Command to configure kubectl |

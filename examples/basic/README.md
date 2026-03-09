# Basic Deployment Example

This example demonstrates the minimum configuration required to deploy Detectify Internal Scanning.

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- VPC with at least 2 private subnets
- Detectify license credentials

## Usage

1. Create `terraform.tfvars` with your values:

   ```hcl
   vpc_id             = "vpc-xxxxx"
   private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

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
   terraform output -raw kubeconfig_command
   
   # run the output of the above command, e.g.
   aws eks update-kubeconfig --region eu-west-1 --name detectify-scanner
   ```

4. Verify pods are running:

   ```bash
   kubectl get pods -n scanner
   ```

## Inputs

| Name | Description | Required |
|------|-------------|----------|
| `name` | Name of deployment | No |
| `vpc_id` | VPC ID | Yes |
| `private_subnet_ids` | Private subnet IDs | Yes |
| `license_key` | Detectify license key | Yes |
| `connector_api_key` | Connector API key | Yes |
| `registry_username` | Registry username | Yes |
| `registry_password` | Registry password | Yes |

## Outputs

| Name | Description |
|------|-------------|
| `kubeconfig_command` | Command to configure kubectl |

# Release Notes Template

This file is used by the CI/CD pipeline to generate GitHub Release content.

## Usage

```hcl
module "internal_scanning" {
  source = "github.com/detectify/terraform-aws-internal-scanning?ref=${VERSION}"

  # Environment
  environment = "production"
  aws_region  = "eu-west-1"

  # Network - use your existing VPC
  vpc_id             = "vpc-xxxxxxxxx"
  private_subnet_ids = ["subnet-xxx", "subnet-yyy"]
  alb_inbound_cidrs  = ["10.0.0.0/16"]  # CIDRs allowed to access the scanner

  # Scanner endpoint
  scanner_url           = "scanner.internal.example.com"
  create_route53_record = true
  route53_zone_id       = "Z0XXXXXXXXXXXXX"

  # Credentials (use variables or secrets manager)
  license_key       = var.detectify_license_key
  connector_api_key = var.detectify_connector_api_key
  registry_username = var.detectify_registry_username
  registry_password = var.detectify_registry_password
}
```

> **Note:** You also need to configure the `kubernetes` and `helm` providers. See the [README](https://github.com/detectify/terraform-aws-internal-scanning/blob/main/README.md) for a complete example.

## Documentation

See the [README](https://github.com/detectify/terraform-aws-internal-scanning/blob/main/README.md) for full documentation and all available variables.

#---------------------------------------------------------------
# Data Sources
#---------------------------------------------------------------

# Current AWS account information
data "aws_caller_identity" "current" {}

# Region used by the provider
data "aws_region" "current" {}

# Get ALB hosted zone ID for the region (for Route53 alias records)
data "aws_elb_hosted_zone_id" "main" {}

locals {
  alb_hosted_zone_id = data.aws_elb_hosted_zone_id.main.id
  account_id         = data.aws_caller_identity.current.account_id
}

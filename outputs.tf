#---------------------------------------------------------------
# EKS Cluster Outputs
#---------------------------------------------------------------

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
  depends_on  = [time_sleep.wait_for_cluster]
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
  depends_on  = [time_sleep.wait_for_cluster]
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
  depends_on  = [time_sleep.wait_for_cluster]
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

#---------------------------------------------------------------
# Scanner Application Outputs
#---------------------------------------------------------------

output "scanner_url" {
  description = "Scanner API endpoint URL"
  value       = "https://${var.scanner_url}"
}

output "scanner_namespace" {
  description = "Kubernetes namespace where scanner is deployed"
  value       = "scanner"
}

output "alb_dns_name" {
  description = "DNS name of the ALB created for scan scheduler"
  value       = var.create_ingress ? try(kubernetes_ingress_v1.scan_scheduler[0].status[0].load_balancer[0].ingress[0].hostname, "") : ""
}

output "alb_zone_id" {
  description = "Route53 zone ID of the ALB (for DNS record creation)"
  value       = local.alb_hosted_zone_id
}

#---------------------------------------------------------------
# Certificate Outputs
#---------------------------------------------------------------

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for scan scheduler"
  value       = var.create_acm_certificate ? aws_acm_certificate.scan_scheduler[0].arn : var.acm_certificate_arn
}

output "acm_certificate_domain_validation_options" {
  description = "Domain validation options for ACM certificate. Use these to create DNS validation records when managing DNS externally (create_route53_record = false)."
  value = var.create_acm_certificate ? [
    for dvo in aws_acm_certificate.scan_scheduler[0].domain_validation_options : {
      domain_name           = dvo.domain_name
      resource_record_name  = dvo.resource_record_name
      resource_record_type  = dvo.resource_record_type
      resource_record_value = dvo.resource_record_value
    }
  ] : []
}

#---------------------------------------------------------------
# IAM Role Outputs
#---------------------------------------------------------------

output "vpc_cni_role_arn" {
  description = "IAM role ARN for VPC CNI addon"
  value       = aws_iam_role.vpc_cni.arn
}

output "cloudwatch_observability_role_arn" {
  description = "IAM role ARN for CloudWatch Observability addon"
  value       = var.enable_cloudwatch_observability ? aws_iam_role.cloudwatch_observability_role[0].arn : null
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.load_balancer_controller_irsa_role.iam_role_arn
}

#---------------------------------------------------------------
# Prometheus Outputs (if enabled)
#---------------------------------------------------------------

output "prometheus_url" {
  description = "Prometheus endpoint URL (if enabled)"
  value       = var.enable_prometheus ? "https://${var.prometheus_url}" : null
}

#---------------------------------------------------------------
# Encryption Outputs
#---------------------------------------------------------------

output "kms_key_arn" {
  description = "ARN of the KMS key used for EKS secrets encryption"
  value       = local.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for EKS secrets encryption (only if created by module)"
  value       = var.kms_key_arn == null ? aws_kms_key.eks_secrets[0].key_id : null
}

#---------------------------------------------------------------
# Configuration Outputs
#---------------------------------------------------------------

output "kubeconfig_command" {
  description = "Command to update kubeconfig for kubectl access"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

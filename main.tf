#---------------------------------------------------------------
# KMS Key for EKS Secrets Encryption
#---------------------------------------------------------------

locals {
  cluster_name = "${var.environment}-${var.cluster_name_prefix}"
  # Use provided KMS key or the one created by this module
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.eks_secrets[0].arn
}

resource "aws_kms_key" "eks_secrets" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "KMS key for EKS secrets encryption - ${local.cluster_name}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${local.cluster_name}-eks-secrets"
  }
}

resource "aws_kms_alias" "eks_secrets" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/${local.cluster_name}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets[0].key_id
}

#---------------------------------------------------------------
# EKS Cluster
#---------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  # KMS encryption for Kubernetes secrets at rest (always enabled)
  cluster_encryption_config = {
    provider_key_arn = local.kms_key_arn
    resources        = ["secrets"]
  }

  # Use API mode instead of CONFIG_MAP to avoid bootstrap permission requirement
  authentication_mode = "API"

  # Control whether the cluster creator gets admin permissions
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Enable EKS Auto Mode for automated node, storage, and load balancer management
  # Note: EKS Auto Mode includes Metrics Server, which is required for HPA (autoscaling)
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # Shorten IAM role name to avoid 38-character limit
  node_iam_role_name            = "${var.environment}-eks-auto"
  node_iam_role_use_name_prefix = false

  # Required for EKS Auto Mode - must be false when cluster_compute_config is enabled
  bootstrap_self_managed_addons = false

  tags = {
    Service = var.cluster_name_prefix
  }

  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules

  cluster_addons = merge(
    {
      coredns = {
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        addon_version               = "v1.13.1-eksbuild.1"
      }
      kube-proxy = {
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        addon_version               = "v1.35.0-eksbuild.2"
      }
      vpc-cni = {
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        service_account_role_arn    = aws_iam_role.vpc_cni.arn
        addon_version               = "v1.21.1-eksbuild.1"
      }
    },
    var.enable_cloudwatch_observability ? {
      amazon-cloudwatch-observability = {
        resolve_conflicts_on_create = "OVERWRITE"
        resolve_conflicts_on_update = "OVERWRITE"
        preserve                    = true
        service_account_role_arn    = aws_iam_role.cloudwatch_observability_role[0].arn
        addon_version               = "v4.10.0-eksbuild.1"
      }
    } : {}
  )

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true

  # Access entries for API authentication mode
  access_entries = {
    for idx, role_arn in var.cluster_admin_role_arns : "admin_${idx}" => {
      principal_arn = role_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}

#---------------------------------------------------------------
# IAM Role for VPC CNI
#---------------------------------------------------------------
resource "aws_iam_role" "vpc_cni" {
  name_prefix = format("%s-vpc-cni-", var.environment)
  description = "The IAM role for VPC CNI addon"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:kube-system:aws-node",
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

#---------------------------------------------------------------
# IAM Role for Amazon CloudWatch Observability
#---------------------------------------------------------------
resource "aws_iam_role" "cloudwatch_observability_role" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  name_prefix = format("%s-cw-", var.environment)
  description = "The IAM role for amazon-cloudwatch-observability addon"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent",
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_policy_attachment" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_observability_role[0].name
}

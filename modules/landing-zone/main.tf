terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  # Common tags for all resources
  common_tags = merge(var.tags, {
    Project     = "multi-account-landing-zone"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  
  # Account structure
  account_structure = {
    security = {
      name        = "Security"
      email       = "${var.organization_prefix}-security@${var.domain_name}"
      description = "Central security and compliance account"
    }
    shared-services = {
      name        = "Shared Services"
      email       = "${var.organization_prefix}-shared-services@${var.domain_name}"
      description = "Shared services and infrastructure"
    }
    dev = {
      name        = "Development"
      email       = "${var.organization_prefix}-dev@${var.domain_name}"
      description = "Development environment"
    }
    staging = {
      name        = "Staging"
      email       = "${var.organization_prefix}-staging@${var.domain_name}"
      description = "Staging environment"
    }
    prod = {
      name        = "Production"
      email       = "${var.organization_prefix}-prod@${var.domain_name}"
      description = "Production environment"
    }
  }
}

# Create AWS Organizations
resource "aws_organizations_organization" "main" {
  count = var.create_organization ? 1 : 0
  
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "organizations.amazonaws.com",
    "account.amazonaws.com"
  ]
  
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]
  
  feature_set = "ALL"
}

# Root Organizational Unit
data "aws_organizations_organization" "main" {
  depends_on = [aws_organizations_organization.main]
}

# Security OU
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization.main.roots[0].id
  tags      = local.common_tags
}

# Workloads OU
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = data.aws_organizations_organization.main.roots[0].id
  tags      = local.common_tags
}

# Environments OU under Workloads
resource "aws_organizations_organizational_unit" "environments" {
  name      = "Environments"
  parent_id = aws_organizations_organizational_unit.workloads.id
  tags      = local.common_tags
}

# Create accounts
resource "aws_organizations_account" "accounts" {
  for_each = var.create_accounts ? local.account_structure : {}
  
  name                       = each.value.name
  email                      = each.value.email
  close_on_deletion         = var.close_accounts_on_deletion
  create_govcloud           = false
  iam_user_access_to_billing = "ALLOW"
  
  # Determine parent OU based on account type
  parent_id = each.key == "security" ? aws_organizations_organizational_unit.security.id : aws_organizations_organizational_unit.environments.id
  
  tags = merge(local.common_tags, {
    AccountType = each.key
  })
  
  lifecycle {
    ignore_changes = [role_name]
  }
}

# Service Control Policies
resource "aws_organizations_policy" "deny_root_user" {
  name        = "DenyRootUser"
  description = "Deny root user access except for specific actions"
  type        = "SERVICE_CONTROL_POLICY"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootUser"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalType" = "Root"
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_organizations_policy" "require_mfa" {
  name        = "RequireMFA"
  description = "Require MFA for sensitive operations"
  type        = "SERVICE_CONTROL_POLICY"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireMFAForSensitiveOperations"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_organizations_policy" "deny_region_restriction" {
  name        = "DenyRegionRestriction"
  description = "Restrict operations to approved regions"
  type        = "SERVICE_CONTROL_POLICY"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllOutsideApprovedRegions"
        Effect = "Deny"
        NotAction = [
          "iam:*",
          "organizations:*",
          "route53:*",
          "cloudfront:*",
          "waf:*",
          "support:*",
          "trustedadvisor:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach SCPs to OUs
resource "aws_organizations_policy_attachment" "deny_root_user_security" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "deny_root_user_workloads" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "require_mfa_security" {
  policy_id = aws_organizations_policy.require_mfa.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "require_mfa_workloads" {
  policy_id = aws_organizations_policy.require_mfa.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_region_restriction_workloads" {
  policy_id = aws_organizations_policy.deny_region_restriction.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# CloudTrail for organization
resource "aws_cloudtrail" "organization_trail" {
  count = var.enable_cloudtrail ? 1 : 0
  
  name                         = "${var.organization_prefix}-organization-trail"
  s3_bucket_name              = aws_s3_bucket.cloudtrail[0].bucket
  s3_key_prefix               = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail       = true
  is_organization_trail       = true
  enable_logging              = true
  
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }
  
  tags = local.common_tags
  
  depends_on = [aws_s3_bucket_policy.cloudtrail[0]]
}

# S3 bucket for CloudTrail
resource "aws_s3_bucket" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  
  bucket        = "${var.organization_prefix}-cloudtrail-${random_string.suffix.result}"
  force_destroy = true
  
  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

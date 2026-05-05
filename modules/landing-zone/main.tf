# Data source for current AWS account
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

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
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "organizations.amazonaws.com",
    "account.amazonaws.com",
    "access-analyzer.amazonaws.com"
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
  close_on_deletion          = true
  create_govcloud            = false
  iam_user_access_to_billing = "DENY"

  # Determine parent OU based on account type
  parent_id = each.key == "security" ? aws_organizations_organizational_unit.security.id : aws_organizations_organizational_unit.environments.id

  tags = merge(local.common_tags, {
    AccountType = each.key
  })

  lifecycle {
    ignore_changes = [role_name]
  }
}

############################################################
# Service Control Policies
############################################################

# Standard pattern: deny actions when the calling principal is the
# account root user. SCPs ignore the `Principal` element entirely;
# the correct pattern is to match aws:PrincipalArn against *:root.
data "aws_iam_policy_document" "deny_root_user" {
  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }
  }
}

resource "aws_organizations_policy" "deny_root_user" {
  name        = "DenyRootUser"
  description = "Deny all actions when invoked by the account root user"
  type        = "SERVICE_CONTROL_POLICY"

  content = data.aws_iam_policy_document.deny_root_user.json

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

# Block tampering with the central security stack: GuardDuty, Security
# Hub, Config, CloudTrail and IAM Access Analyzer.
resource "aws_organizations_policy" "deny_disable_security_services" {
  name        = "DenyDisableSecurityServices"
  description = "Prevent disabling or tampering with org-wide security services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDisableSecurityServices"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DeleteMembers",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:DisassociateMembers",
          "guardduty:DisableOrganizationAdminAccount",
          "guardduty:StopMonitoringMembers",
          "guardduty:UpdateDetector",
          "securityhub:DisableSecurityHub",
          "securityhub:DisableImportFindingsForProduct",
          "securityhub:DisableOrganizationAdminAccount",
          "securityhub:DisassociateFromMasterAccount",
          "securityhub:DisassociateMembers",
          "securityhub:DeleteMembers",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:DeleteConfigRule",
          "config:DeleteOrganizationConfigRule",
          "config:DeleteConfigurationAggregator",
          "config:StopConfigurationRecorder",
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail",
          "cloudtrail:PutEventSelectors",
          "accessanalyzer:DeleteAnalyzer"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Prevent member accounts from leaving the organization on their own.
resource "aws_organizations_policy" "deny_leave_organization" {
  name        = "DenyLeaveOrganization"
  description = "Prevent member accounts from leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeaveOrganization"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Require IMDSv2 on all new EC2 instances.
resource "aws_organizations_policy" "require_imdsv2" {
  name        = "RequireIMDSv2"
  description = "Deny RunInstances unless IMDSv2 (HttpTokens=required) is enforced"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRunInstancesWithoutIMDSv2"
        Effect   = "Deny"
        Action   = ["ec2:RunInstances"]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotEquals = {
            "ec2:MetadataHttpTokens" = "required"
          }
        }
      },
      {
        Sid      = "DenyModifyInstanceMetadataOptionsToOptional"
        Effect   = "Deny"
        Action   = ["ec2:ModifyInstanceMetadataOptions"]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotEquals = {
            "ec2:MetadataHttpTokens" = "required"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Block the most common patterns of accidentally publicising S3 data.
resource "aws_organizations_policy" "deny_s3_public_acl" {
  name        = "DenyS3PublicAcl"
  description = "Prevent disabling S3 public access block and public ACLs"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyDisablePublicAccessBlock"
        Effect   = "Deny"
        Action   = ["s3:PutBucketPublicAccessBlock"]
        Resource = "*"
        Condition = {
          Bool = {
            "s3:PublicAccessBlockConfiguration.BlockPublicAcls"       = "false"
            "s3:PublicAccessBlockConfiguration.BlockPublicPolicy"     = "false"
            "s3:PublicAccessBlockConfiguration.IgnorePublicAcls"      = "false"
            "s3:PublicAccessBlockConfiguration.RestrictPublicBuckets" = "false"
          }
        }
      },
      {
        Sid      = "DenyPublicBucketAcl"
        Effect   = "Deny"
        Action   = ["s3:PutBucketAcl"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"]
          }
        }
      },
      {
        Sid      = "DenyPublicObjectAcl"
        Effect   = "Deny"
        Action   = ["s3:PutObjectAcl"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"]
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Protect KMS keys from accidental deletion / disable. Break-glass is
# possible only via the account root user (which is itself denied above
# unless DenyRootUser is detached as part of the break-glass procedure).
resource "aws_organizations_policy" "deny_kms_key_deletion" {
  name        = "DenyKmsKeyDeletion"
  description = "Prevent KMS key deletion / disable except by root"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyKmsKeyDeletion"
        Effect = "Deny"
        Action = [
          "kms:ScheduleKeyDeletion",
          "kms:DisableKey"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalArn" = ["arn:aws:iam::*:root"]
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

############################################################
# Attach SCPs to OUs
############################################################

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

resource "aws_organizations_policy_attachment" "deny_disable_security_services_workloads" {
  policy_id = aws_organizations_policy.deny_disable_security_services.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_disable_security_services_security" {
  policy_id = aws_organizations_policy.deny_disable_security_services.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "deny_leave_organization_workloads" {
  policy_id = aws_organizations_policy.deny_leave_organization.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_leave_organization_security" {
  policy_id = aws_organizations_policy.deny_leave_organization.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "require_imdsv2_workloads" {
  policy_id = aws_organizations_policy.require_imdsv2.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_s3_public_acl_workloads" {
  policy_id = aws_organizations_policy.deny_s3_public_acl.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_s3_public_acl_security" {
  policy_id = aws_organizations_policy.deny_s3_public_acl.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "deny_kms_key_deletion_workloads" {
  policy_id = aws_organizations_policy.deny_kms_key_deletion.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

############################################################
# Delegated administrators (security account owns these services)
############################################################

resource "aws_organizations_delegated_administrator" "guardduty" {
  count = var.enable_guardduty && var.create_accounts ? 1 : 0

  account_id        = aws_organizations_account.accounts["security"].id
  service_principal = "guardduty.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "securityhub" {
  count = var.enable_security_hub && var.create_accounts ? 1 : 0

  account_id        = aws_organizations_account.accounts["security"].id
  service_principal = "securityhub.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "config_multiaccount" {
  count = var.enable_config && var.create_accounts ? 1 : 0

  account_id        = aws_organizations_account.accounts["security"].id
  service_principal = "config-multiaccountsetup.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "accessanalyzer" {
  count = var.create_accounts ? 1 : 0

  account_id        = aws_organizations_account.accounts["security"].id
  service_principal = "access-analyzer.amazonaws.com"
}

############################################################
# GuardDuty (org-level wiring; runs in management account)
############################################################

resource "aws_guardduty_detector" "management" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = local.common_tags
}

resource "aws_guardduty_organization_admin_account" "this" {
  count = var.enable_guardduty && var.create_accounts ? 1 : 0

  admin_account_id = aws_organizations_account.accounts["security"].id

  depends_on = [
    aws_organizations_delegated_administrator.guardduty,
    aws_guardduty_detector.management,
  ]
}

resource "aws_guardduty_organization_configuration" "this" {
  count = var.enable_guardduty ? 1 : 0

  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.management[0].id

  datasources {
    s3_logs {
      auto_enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = true
        }
      }
    }
  }

  depends_on = [aws_guardduty_organization_admin_account.this]
}

############################################################
# Security Hub (org-level wiring + standards subscriptions)
############################################################

resource "aws_securityhub_account" "management" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_organization_admin_account" "this" {
  count = var.enable_security_hub && var.create_accounts ? 1 : 0

  admin_account_id = aws_organizations_account.accounts["security"].id

  depends_on = [
    aws_organizations_delegated_administrator.securityhub,
    aws_securityhub_account.management,
  ]
}

resource "aws_securityhub_organization_configuration" "this" {
  count = var.enable_security_hub ? 1 : 0

  auto_enable = true

  depends_on = [aws_securityhub_organization_admin_account.this]
}

resource "aws_securityhub_standards_subscription" "afsbp" {
  count = var.enable_security_hub ? 1 : 0

  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.management]
}

resource "aws_securityhub_standards_subscription" "cis_1_4" {
  count = var.enable_security_hub ? 1 : 0

  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.management]
}

############################################################
# IAM Access Analyzer at the organization scope
############################################################

resource "aws_accessanalyzer_analyzer" "organization" {
  analyzer_name = "${var.organization_prefix}-org-analyzer"
  type          = "ORGANIZATION"

  tags = local.common_tags

  depends_on = [aws_organizations_delegated_administrator.accessanalyzer]
}

############################################################
# AWS Config
#
# TODO: Full multi-account aggregator setup (configuration recorder,
# delivery channel, organization aggregator and conformance packs) is
# heavy and typically lives in the delegated security account. For now
# we only register the security account as the delegated admin via
# `aws_organizations_delegated_administrator.config_multiaccount` above
# and rely on Control Tower / per-account Terraform to do the rest.
############################################################

############################################################
# CloudTrail for organization (KMS-encrypted, log-validated)
############################################################

# KMS key used to encrypt the organization trail.
resource "aws_kms_key" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  description             = "KMS key for organization CloudTrail"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/${var.organization_prefix}-organization-trail"
          }
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowCloudTrailDecryptForLogReaders"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_kms_alias" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  name          = "alias/${var.organization_prefix}-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail[0].key_id
}

resource "aws_cloudtrail" "organization_trail" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.organization_prefix}-organization-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].bucket
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail[0].arn

  event_selector {
    read_write_type                  = "All"
    include_management_events        = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }

  tags = local.common_tags

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# S3 bucket for CloudTrail. Object Lock must be enabled at create time.
resource "aws_s3_bucket" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket              = "${var.organization_prefix}-cloudtrail-${random_string.suffix.result}"
  force_destroy       = false
  object_lock_enabled = true

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
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cloudtrail[0].arn
    }
    bucket_key_enabled = true
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

# Lifecycle: keep in Standard for 90 days then Glacier; expire after 7 years.
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "archive-then-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # ~7 years
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 2555
    }
  }
}

# Object Lock in governance mode for 7 years to satisfy WORM-style audit
# requirements. Requires `object_lock_enabled = true` on the bucket.
resource "aws_s3_bucket_object_lock_configuration" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 2555
    }
  }
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
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/${var.organization_prefix}-organization-trail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/cloudtrail/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceArn"     = "arn:${data.aws_partition.current.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/${var.organization_prefix}-organization-trail"
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail[0].arn,
          "${aws_s3_bucket.cloudtrail[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
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

output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = var.create_organization ? aws_organizations_organization.main[0].id : data.aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organization"
  value       = var.create_organization ? aws_organizations_organization.main[0].arn : data.aws_organizations_organization.main.arn
}

output "master_account_id" {
  description = "The master account ID"
  value       = var.create_organization ? aws_organizations_organization.main[0].master_account_id : data.aws_organizations_organization.main.master_account_id
}

output "root_id" {
  description = "The root organizational unit ID"
  value       = data.aws_organizations_organization.main.roots[0].id
}

output "security_ou_id" {
  description = "The Security organizational unit ID"
  value       = aws_organizations_organizational_unit.security.id
}

output "workloads_ou_id" {
  description = "The Workloads organizational unit ID"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "environments_ou_id" {
  description = "The Environments organizational unit ID"
  value       = aws_organizations_organizational_unit.environments.id
}

output "account_ids" {
  description = "Map of account names to account IDs"
  value = {
    for k, v in aws_organizations_account.accounts : k => v.id
  }
}

output "account_emails" {
  description = "Map of account names to account emails"
  value = {
    for k, v in aws_organizations_account.accounts : k => v.email
  }
}

output "service_control_policies" {
  description = "Map of Service Control Policy names to policy IDs"
  value = {
    deny_root_user          = aws_organizations_policy.deny_root_user.id
    require_mfa             = aws_organizations_policy.require_mfa.id
    deny_region_restriction = aws_organizations_policy.deny_region_restriction.id
  }
}

output "cloudtrail_arn" {
  description = "The ARN of the organization CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.organization_trail[0].arn : null
}

output "cloudtrail_bucket_name" {
  description = "The name of the CloudTrail S3 bucket"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].bucket : null
}

output "account_structure" {
  description = "Complete account structure information"
  value = {
    for k, v in aws_organizations_account.accounts : k => {
      id           = v.id
      arn          = v.arn
      email        = v.email
      name         = v.name
      status       = v.status
      parent_ou    = v.parent_id
      account_type = k
    }
  }
}

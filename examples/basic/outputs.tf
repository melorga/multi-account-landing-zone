output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = module.landing_zone.organization_id
}

output "organization_arn" {
  description = "The ARN of the AWS Organization"
  value       = module.landing_zone.organization_arn
}

output "master_account_id" {
  description = "The master account ID"
  value       = module.landing_zone.master_account_id
}

output "security_ou_id" {
  description = "The Security organizational unit ID"
  value       = module.landing_zone.security_ou_id
}

output "workloads_ou_id" {
  description = "The Workloads organizational unit ID"
  value       = module.landing_zone.workloads_ou_id
}

output "environments_ou_id" {
  description = "The Environments organizational unit ID"
  value       = module.landing_zone.environments_ou_id
}

output "account_ids" {
  description = "Map of account names to account IDs"
  value       = module.landing_zone.account_ids
}

output "cloudtrail_arn" {
  description = "The ARN of the organization CloudTrail"
  value       = module.landing_zone.cloudtrail_arn
}

output "service_control_policies" {
  description = "Map of Service Control Policy names to policy IDs"
  value       = module.landing_zone.service_control_policies
}

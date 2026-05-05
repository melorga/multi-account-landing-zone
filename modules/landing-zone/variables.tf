variable "organization_prefix" {
  description = "Prefix for organization resources and email addresses"
  type        = string
  default     = "acme"
}

variable "domain_name" {
  description = "Domain name for organization email addresses"
  type        = string
  default     = "example.com"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "create_organization" {
  description = "Whether to create AWS Organizations (set to false if organization already exists)"
  type        = bool
  default     = true
}

variable "create_accounts" {
  description = "Whether to create member accounts"
  type        = bool
  default     = true
}

variable "close_accounts_on_deletion" {
  description = "Deprecated: accounts are now always closed on deletion. Retained for backwards compatibility."
  type        = bool
  default     = true
}

variable "allowed_regions" {
  description = "List of allowed AWS regions"
  type        = list(string)
  default = [
    "us-east-1",
    "us-west-2",
    "eu-west-1"
  ]
}

variable "enable_cloudtrail" {
  description = "Enable organization-wide CloudTrail"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config organization-wide (registers the security account as the delegated admin for config-multiaccountsetup)"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty organization-wide"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub organization-wide"
  type        = bool
  default     = true
}

variable "enable_identity_center" {
  description = "Provision IAM Identity Center permission sets (requires Identity Center to already be enabled in the management account)"
  type        = bool
  default     = false
}

variable "cloudtrail_retention_days" {
  description = "CloudTrail log retention in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

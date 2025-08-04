variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "organization_prefix" {
  description = "Prefix for organization resources"
  type        = string
  default     = "demo-org"
}

variable "domain_name" {
  description = "Domain name for organization email addresses"
  type        = string
  default     = "example.com"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "create_organization" {
  description = "Whether to create AWS Organizations"
  type        = bool
  default     = true
}

variable "create_accounts" {
  description = "Whether to create member accounts"
  type        = bool
  default     = false  # Set to false for demo to avoid creating real accounts
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

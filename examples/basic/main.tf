terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "landing_zone" {
  source = "../../modules/landing-zone"

  organization_prefix = var.organization_prefix
  domain_name        = var.domain_name
  environment        = var.environment

  # Organization settings
  create_organization = var.create_organization
  create_accounts     = var.create_accounts

  # Regional restrictions
  allowed_regions = var.allowed_regions

  # Security services
  enable_cloudtrail   = true
  enable_config      = true
  enable_guardduty   = true
  enable_security_hub = true

  # CloudTrail settings
  cloudtrail_retention_days = 365

  tags = {
    Project     = "multi-account-landing-zone"
    Environment = var.environment
    Owner       = "Platform Team"
    CostCenter  = "Infrastructure"
  }
}

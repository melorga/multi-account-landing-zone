# `landing-zone` module

Bootstraps an AWS multi-account landing zone: AWS Organizations,
opinionated SCPs, organization CloudTrail (KMS-encrypted, log file
validation, S3 Object Lock), GuardDuty / Security Hub / Access Analyzer
org wiring and an opt-in IAM Identity Center scaffold.

## Usage

The simplest possible wiring lives in
[`examples/basic`](../../examples/basic):

```hcl
module "landing_zone" {
  source = "../../modules/landing-zone"

  organization_prefix = "acme"
  domain_name         = "example.com"
  environment         = "prod"

  create_organization = true
  create_accounts     = true

  allowed_regions = ["us-east-1", "us-west-2", "eu-west-1"]

  enable_cloudtrail      = true
  enable_config          = true
  enable_guardduty       = true
  enable_security_hub    = true
  enable_identity_center = false # flip to true once IdC is enabled in the management account

  tags = {
    Project    = "multi-account-landing-zone"
    CostCenter = "Infrastructure"
  }
}
```

Apply from the management account with credentials that have
`AWSOrganizationsFullAccess` plus the various `*OrganizationAdminAccount`
permissions.

## Inputs

| Name                          | Type           | Default                                  | Description                                                          |
| ----------------------------- | -------------- | ---------------------------------------- | -------------------------------------------------------------------- |
| `organization_prefix`         | `string`       | `"acme"`                                 | Prefix for resource names and account email aliases                   |
| `domain_name`                 | `string`       | `"example.com"`                          | Email domain for account aliases (`<prefix>-<role>@<domain>`)         |
| `environment`                 | `string`       | `"prod"`                                 | Environment tag                                                       |
| `create_organization`         | `bool`         | `true`                                   | Create AWS Organizations (set `false` if it already exists)           |
| `create_accounts`             | `bool`         | `true`                                   | Create the security/shared/dev/staging/prod member accounts           |
| `allowed_regions`             | `list(string)` | `["us-east-1","us-west-2","eu-west-1"]`  | Regions allowed by the `DenyRegionRestriction` SCP                    |
| `enable_cloudtrail`           | `bool`         | `true`                                   | Provision the org-wide CloudTrail and its KMS-encrypted bucket        |
| `enable_config`               | `bool`         | `true`                                   | Register the security account as the Config delegated admin          |
| `enable_guardduty`            | `bool`         | `true`                                   | Enable org-wide GuardDuty                                             |
| `enable_security_hub`         | `bool`         | `true`                                   | Enable org-wide Security Hub + AFSBP and CIS 1.4 standards            |
| `enable_identity_center`      | `bool`         | `false`                                  | Provision IAM Identity Center permission sets                        |
| `cloudtrail_retention_days`   | `number`       | `90`                                     | (Reserved) CloudTrail log retention window                            |
| `tags`                        | `map(string)`  | `{}`                                     | Additional tags merged into every resource                            |

## Outputs

See [`outputs.tf`](outputs.tf) for the full list. Highlights:

- `organization_id`, `organization_arn`, `master_account_id`
- `security_ou_id`, `workloads_ou_id`, `environments_ou_id`
- `account_ids`, `account_emails`, `account_structure`
- `service_control_policies`
- `cloudtrail_arn`, `cloudtrail_bucket_name`

## Notes

- `aws_organizations_account` resources cannot be re-imported once an
  account is closed, so destroy operations now actually close accounts
  (`close_on_deletion = true`).
- IAM Identity Center must already be enabled in the management account
  before flipping `enable_identity_center = true`.
- Full AWS Config aggregator + recorder + delivery channel setup is
  intentionally out of scope; this module only wires the delegated
  administrator.

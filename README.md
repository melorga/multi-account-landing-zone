# Multi-Account Landing Zone

[![AWS](https://img.shields.io/badge/AWS-Organizations%20%7C%20SCPs%20%7C%20CloudTrail-FF9900?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D%201.9-7B42BC?style=for-the-badge&logo=terraform)](https://terraform.io/)

Terraform module that bootstraps an AWS multi-account landing zone with
AWS Organizations, opinionated Service Control Policies, an
organization-wide CloudTrail and the org-level wiring for GuardDuty,
Security Hub and IAM Access Analyzer.

## Architecture

```
+-----------------+    +-----------------+    +-----------------+
| Management      |    |   Security      |    |   Shared        |
| Account         |--->|   Account       |--->|   Services      |
| (Organizations) |    | (Audit/Logging) |    |   Account       |
+-----------------+    +-----------------+    +-----------------+
         |                      |                      |
         v                      v                      v
+-----------------+    +-----------------+    +-----------------+
|   Production    |    |    Staging      |    |  Development    |
|   Workloads     |    |   Workloads     |    |   Workloads     |
+-----------------+    +-----------------+    +-----------------+
```

## What this module ships

### Organizations
- AWS Organizations with `feature_set = ALL`
- `Security`, `Workloads`, and `Workloads/Environments` OUs
- Member accounts: `security`, `shared-services`, `dev`, `staging`,
  `prod` (closed on deletion, billing access denied)

### Service Control Policies
| SCP                              | Purpose                                                                   |
| -------------------------------- | ------------------------------------------------------------------------- |
| `DenyRootUser`                   | Deny everything when invoked by the account root user                     |
| `RequireMFA`                     | Deny IAM/Organizations/account changes without MFA                        |
| `DenyRegionRestriction`          | Deny calls outside `var.allowed_regions` (excluding global services)      |
| `DenyDisableSecurityServices`    | Block tampering with GuardDuty/SecurityHub/Config/CloudTrail/AccessAnalyzer |
| `DenyLeaveOrganization`          | Block `organizations:LeaveOrganization`                                   |
| `RequireIMDSv2`                  | Deny `ec2:RunInstances` unless `MetadataHttpTokens=required`              |
| `DenyS3PublicAcl`                | Block public bucket / object ACLs and disabling Public Access Block       |
| `DenyKmsKeyDeletion`             | Block `kms:ScheduleKeyDeletion`/`DisableKey` except for break-glass via root |

### Centralised security
- Organization CloudTrail (multi-region, KMS-encrypted, log file
  validation on, lifecycle to Glacier @ 90d, 7-year retention, S3
  Object Lock in governance mode)
- GuardDuty: organization admin delegation + auto-enable for new
  members
- Security Hub: organization admin delegation + AWS Foundational
  Security Best Practices and CIS 1.4 standards subscriptions
- IAM Access Analyzer at organization scope
- AWS Config: security account registered as
  `config-multiaccountsetup` delegated administrator (full aggregator
  setup is left to a follow-up module)
- Optional IAM Identity Center scaffolding (gated by
  `enable_identity_center`)

## Requirements

- AWS CLI configured with Organization management permissions
- Terraform `>= 1.9, < 2.0`
- AWS provider `~> 6.0`

## Quick start

```bash
git clone https://github.com/melorga/multi-account-landing-zone.git
cd multi-account-landing-zone/examples/basic

terraform init
terraform plan
terraform apply
```

See [`examples/basic`](examples/basic) for the canonical wiring.

## Account structure

| Account Type    | Purpose                          | Security Level |
| --------------- | -------------------------------- | -------------- |
| Management      | AWS Organizations, billing       | High           |
| Security        | Audit, logging, monitoring       | Critical       |
| Shared Services | DNS, AD, shared resources        | Medium         |
| Production      | Live workloads                   | High           |
| Staging         | Pre-production testing           | Medium         |
| Development     | Development workloads            | Low            |

## Roadmap (not yet implemented)

The following capabilities are intentionally *not* implemented in this
module today and are tracked as roadmap items:

- AWS Control Tower enablement / landing zone version pinning
- AWS Service Catalog product portfolios
- CloudFormation StackSets for cross-account deployments
- Account Vending Machine (automated account creation API)
- AWS Config conformance packs / managed rule packs
- Reserved Instance / Savings Plan sharing automation
- AWS Budgets and budget action wiring

PRs welcome.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run `terraform fmt -recursive` and `terraform validate`
4. Open a pull request

## License

MIT - see [LICENSE](LICENSE).

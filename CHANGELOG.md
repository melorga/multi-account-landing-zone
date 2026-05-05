# Changelog

All notable changes to this project will be documented in this file.
The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - audit fixes

### Fixed
- `DenyRootUser` SCP rewritten using the standard `aws:PrincipalArn`
  pattern; the previous form used `Principal` (ignored in SCPs) and the
  non-standard `aws:PrincipalType = "Root"`.
- CloudTrail bucket policy now includes the `aws:SourceArn` and
  `aws:SourceAccount` conditions required by CloudTrail.
- CI: removed unreachable `if [ $? -ne 0 ]` after `set -e` /
  `terraform fmt -check`.
- Account creation now sets `iam_user_access_to_billing = "DENY"` and
  `close_on_deletion = true`.

### Added
- New SCPs: `DenyDisableSecurityServices`, `DenyLeaveOrganization`,
  `RequireIMDSv2`, `DenyS3PublicAcl`, `DenyKmsKeyDeletion`.
- Org-wide GuardDuty (admin delegation + auto-enable for new members).
- Org-wide Security Hub with AFSBP and CIS 1.4 standards subscriptions.
- IAM Access Analyzer at organization scope.
- AWS Config delegated-administrator wiring for the security account.
- KMS key + alias for CloudTrail encryption (`enable_key_rotation =
  true`).
- CloudTrail `enable_log_file_validation = true`.
- S3 lifecycle (Glacier @ 90d, expiry @ 7y) and Object Lock
  (governance, 7y) on the trail bucket.
- Optional IAM Identity Center scaffold (`enable_identity_center`).
- `.github/dependabot.yml`, `CODEOWNERS`, `SECURITY.md`, this changelog.

### Changed
- Bumped `required_version` to `>= 1.9, < 2.0` and the AWS provider to
  `~> 6.0`. Extracted the `terraform { ... }` block into
  `modules/landing-zone/versions.tf`.
- CI now uses OIDC (`aws-actions/configure-aws-credentials@v4` +
  `role-to-assume`) instead of long-lived access keys; pins
  `bridgecrewio/checkov-action@v12.2.870` and
  `aquasecurity/trivy-action@0.28.0`; gates apply on `workflow_dispatch`.
- README trims unimplemented Control Tower / Service Catalog /
  StackSets / Account Vending / RI / Config Rule / Budgets claims into
  a Roadmap section, fixes the `melorga-portfolio` clone URL and bumps
  the documented Terraform version to `>= 1.9`.
- `.gitignore` no longer blanket-ignores `*.md`.

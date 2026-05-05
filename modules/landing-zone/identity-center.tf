# IAM Identity Center (AWS SSO) scaffolding.
#
# NOTE: IAM Identity Center must already be enabled in the management
# account (via the AWS Console -> IAM Identity Center -> Enable). This
# module discovers the existing instance via the data source below and
# layers a baseline permission set on top.
#
# Everything in this file is gated by `var.enable_identity_center`
# (default `false`) so the module remains backwards compatible.

data "aws_ssoadmin_instances" "this" {
  count = var.enable_identity_center ? 1 : 0
}

locals {
  sso_instance_arn = var.enable_identity_center ? tolist(data.aws_ssoadmin_instances.this[0].arns)[0] : null
}

# Example baseline permission set: full administrator access. Real
# deployments should add ReadOnly, PowerUser, Billing, etc. and assign
# them to specific groups via aws_ssoadmin_account_assignment.
resource "aws_ssoadmin_permission_set" "administrator_access" {
  count = var.enable_identity_center ? 1 : 0

  name             = "AdministratorAccess"
  description      = "Full administrator access (managed by Terraform)"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = local.common_tags
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator_access" {
  count = var.enable_identity_center ? 1 : 0

  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.administrator_access[0].arn
}

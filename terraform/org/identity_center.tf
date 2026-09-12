data "aws_ssoadmin_instances" "identity_center" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
}

resource "aws_identitystore_group" "platform_admins" {
  display_name      = "PlatformAdmins"
  description       = "Group with full administator access across all accounts. Includes members of the Platform team."
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "security_analysts" {
  display_name      = "SecurityAnalysts"
  description       = "Group performs investigations, log monitoring, and audits. Includes members of the Security team."
  identity_store_id = local.identity_store_id
}

resource "aws_ssoadmin_permission_set" "platform_admin" {
  name             = "PlatformAdmin"
  description      = "Full administrative access across all accounts. Log integrity in Security Tooling is enforced by SCP, not by scoping this set."
  instance_arn     = local.instance_arn
  session_duration = "PT1H"

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "platform_admin" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

  depends_on = [
    aws_ssoadmin_account_assignment.platform_admin_mgmt,
    aws_ssoadmin_account_assignment.platform_admin_security_tooling,
    aws_ssoadmin_account_assignment.platform_admin_sandbox,
  ]
}

resource "aws_ssoadmin_account_assignment" "platform_admin_mgmt" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
  principal_id       = aws_identitystore_group.platform_admins.group_id
  principal_type     = "GROUP"
  target_id          = "933613018572"
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_admin_security_tooling" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
  principal_id       = aws_identitystore_group.platform_admins.group_id
  principal_type     = "GROUP"
  target_id          = "886126521429"
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_admin_sandbox" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
  principal_id       = aws_identitystore_group.platform_admins.group_id
  principal_type     = "GROUP"
  target_id          = "560628764625"
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_permission_set" "security_analyst" {
  name             = "SecurityAnalyst"
  description      = "Security investigation access across all accounts."
  instance_arn     = local.instance_arn
  session_duration = "PT4H"

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "security_analyst" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_analyst.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"

  depends_on = [
    aws_ssoadmin_account_assignment.security_analyst_mgmt,
    aws_ssoadmin_account_assignment.security_analyst_security_tooling,
    aws_ssoadmin_account_assignment.security_analyst_sandbox,
  ]
}

resource "aws_ssoadmin_account_assignment" "security_analyst_mgmt" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_analyst.arn
  principal_id       = aws_identitystore_group.security_analysts.group_id
  principal_type     = "GROUP"
  target_id          = "933613018572"
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "security_analyst_security_tooling" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_analyst.arn
  principal_id       = aws_identitystore_group.security_analysts.group_id
  principal_type     = "GROUP"
  target_id          = "886126521429"
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "security_analyst_sandbox" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_analyst.arn
  principal_id       = aws_identitystore_group.security_analysts.group_id
  principal_type     = "GROUP"
  target_id          = "560628764625"
  target_type        = "AWS_ACCOUNT"
}

resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    # Grants trusted access for CloudTrail, GuardDuty, and Access Analyzer
    "cloudtrail.amazonaws.com",
    "guardduty.amazonaws.com",
    "access-analyzer.amazonaws.com",
  ]
  # enables all features in the organization, which is required for SCPs and other advanced features
  # no downgrade path, so be sure you want this before applying
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
  ]
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "sandbox" {
  name      = "Sandbox"
  email     = "cloudadmin.desireepaya+sandbox@gmail.com"
  parent_id = aws_organizations_organizational_unit.workloads.id

  lifecycle {
    # defensive pattern to prevent TF from attempting to replace the account if email changes
    ignore_changes = [email]
  }
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "security_tooling" {
  name      = "Security Tooling"
  email     = "cloudadmin.desireepaya+security-tooling@gmail.com"
  parent_id = aws_organizations_organizational_unit.security.id

  lifecycle {
    ignore_changes = [email]
  }
}

resource "aws_guardduty_organization_admin_account" "security_tooling" {
  admin_account_id = aws_organizations_account.security_tooling.id
}

resource "aws_organizations_delegated_administrator" "access_analyzer" {
  account_id        = aws_organizations_account.security_tooling.id
  service_principal = "access-analyzer.amazonaws.com"
}

resource "aws_iam_service_linked_role" "access_analyzer" {
  aws_service_name = "access-analyzer.amazonaws.com"
}

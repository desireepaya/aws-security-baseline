resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    # pre-enable CloudTrail trusted access to unblock work in Phase 2
    "cloudtrail.amazonaws.com",
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

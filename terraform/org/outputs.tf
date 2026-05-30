output "organization_id" {
  value       = aws_organizations_organization.this.id
  description = "The ID of the AWS Organization created by this module. Referenced by SCPs and resource policies that scope to the organization level."
}

output "organization_root_id" {
  value       = aws_organizations_organization.this.roots[0].id
  description = "The ID of the root OU ID. SCPs attach at the root or to child OUs."
}
output "workloads_ou_id" {
  value       = aws_organizations_organizational_unit.workloads.id
  description = "The ID of the Workloads OU. SCPs intended for all workload accounts attach here."
}

output "sandbox_account_id" {
  value       = aws_organizations_account.sandbox.id
  description = "The ID of the Sandbox account. Used for cross-account role assumption in Phase 2 work."
}


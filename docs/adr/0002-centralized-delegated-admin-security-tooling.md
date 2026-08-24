# ADR-0002: Centralized Delegated Admin in Security Tooling
Status: Accepted

Date: 2026-AUG-19

## Context
A separate Security OU and Security Tooling account were created to reduce dependency on the Management account for daily operations.  Security tools like GuardDuty and Access Analyzer require permissions that are only available from the Management account, primarily access to all child accounts in the organization.  Delegating administration of security tools to the Security Tooling account allows it to access accounts within the organization and manage their configuration.

I chose not to configure and manage security tooling in each account separately because I wanted to replicate the expected enterprise deployment pattern.  Centralizing administration also allows me to auto-enroll any new account should this portfolio expand in the future.  This saves future me management overhead while ensuring new accounts comply with the secure baseline.

## Decision
I delegated administration of security tools to the Security Tooling account.  This includes GuardDuty Detector and Access Analyzer.

## Consequences
Configuring delegated admin supports the account boundary goal established in [ADR-0001: Security Tooling Account and Security OU](../adr/0001-security-tooling-account.md), and centralizes administration for the organization in the Security Tooling account.

However, the delegation mechanism isn't consistent across AWS services.  GuardDuty's dedicated resource [(`aws_guardduty_organization_admin_account`)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_organization_admin_account) provisions the necessary service-linked role automatically.  Lacking a specific delegation resource, Access Analyzer uses the generic [`aws_organizations_delegated_administrator`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_delegated_administrator) which requires the provisioning of a separate role using [`aws_iam_service_linked_role`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role).

## Related
I discovered that a trial detector is provisioned automatically after GuardDuty is enabled for the first time on an account.  That led me through an interesting troubleshooting exercise, see [build notes: 2026-AUG-18](../build_notes.md) for more details.


# ADR-0001: Security Tooling Account and Security OU

Status: Accepted

Date: 2026-Aug-12

# Context
With the foundational components in place, I need to define where security tooling lives.  The Phase 1 organization structure only has the Management account and one Workloads OU.  Neither location is appropriate for these services.  Having security findings in the Management account means logging into it for daily operations.  That creates risk for my most privileged account.  Even when attached at root, SCPs don’t constrain the Management account, so the more secure approach is to keep it empty.

Security services don’t belong in the Workloads OU either, since that also creates a blast radius issue if an account in that OU is compromised.  Security services should be separate from both Workloads and the Management account to mirror common production patterns.

This work is better done now before security services are enabled.  Services in-scope for Phase 2 support delegated administration from the Management account.  If I enabled them now in the Management account, it would simplify the implementation, but would be more difficult to delegate administration later.

# Decision
To align with [AWS’s own security reference architecture](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/introduction.html), I’m creating a new Security OU, which will include the Security Tooling account.  This ensures I can delegate administrative permissions to security services from the Management account, removing the need to use it for daily operations.  It also separates member accounts in the Workloads OU from security tooling.

This leverages the delegated admin support that already exists for the security services in-scope: GuardDuty, Config, and Access Analyzer.

- **OU name:** Security 
- **Account name:** security-tooling 
- **Account email:** cloudadmin.desireepaya+security-tooling@gmail.com 

# Consequences
Updating the Portfolio Organization improves security posture by adopting AWS’s security reference architecture.  There’s a clear distinction between OU functions, and risk to the Management account is reduced.

However, since the `OrganizationAccountAccessRole` is provisioned in new accounts automatically, a user with long-lived credentials (`portfolio-admin`) can assume this role to gain access to two accounts, increasing the blast radius of those credentials. This is a known risk since I deferred the Identity Center work to later in Phase 2.

Adding a second account creates complexity.  Terraform needs to authenticate to two accounts in order to make changes, which means adding a provider alias.  This creates another chicken-and-egg problem with account and resource creation.  Terraform resolves provider configuration before it builds the resource graph.  I can’t reference an account ID if the account doesn’t already exist. The solution is to run apply twice: the first creates the new account, then updates the provider with an alias that assumes a role into the new account.

After reviewing the existing SCPs, both attach to the Workloads OU only.  The new Security OU will inherit nothing beyond the default.  That means the account holding org-wide security findings would be the least constrained account after the Management account.  I need to evaluate the Security account use case before applying guardrails to its OU.  That is deferred and will be tracked separate from this document.

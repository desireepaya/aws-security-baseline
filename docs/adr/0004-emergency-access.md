# ADR-0004: Emergency Access
Status: Accepted

Date: 2026-SEP-18

## Context
Implementing Identity Center (IDC) established a human path that doesn't rely on long-lived credentials.  It also introduced a known risk: if IDC wasn't available for some reason, I would lose access to the environment.  Emergency access has a single purpose: restoring the human path, but I won't be able to predict what will be broken.  It shouldn't need to resolve issues with either the Security Tooling or Sandbox accounts.

## Decision
I will create an IAM user, `break-glass`, with no permissions and no access keys.  This user will need to assume a role to elevate its permissions.  The new role will be managed by Terraform with `AdministratorAccess`, and a trust policy that limits role assumption to `break-glass` and only with MFA.  I'll configure alerts on role assumption using EventBridge and SNS.

## Alternatives Considered
I could have limited the policy to just Identity Center repair plus read access, but a scoped policy has the potential to fail at the exact time it's needed.  If the regular path for human access is unavailable, so is the ability to update access permissions.  Admin access ensures this role has sufficient permissions to resolve an issue quickly.  Risk can be managed by limiting the user to console, requiring MFA in the trust policy, and alerting on every role assumption.

## Consequences
A standing admin-capable path to the management account is a risk.  The compensating control is the detection rule, which is prioritized as the next build task.  This user exists outside of Terraform, so no errant `apply` can remove my recovery path.

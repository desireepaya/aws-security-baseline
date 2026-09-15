# ADR-0003: Identity Foundation
Status: Accepted

Date: 2026-AUG-24

## Context
The portfolio project currently relies on an IAM principal with long-lived credentials.  This was an explicit decision in order to bootstrap the environment.  Now is a reasonable time to migrate to a solution that enforces short-term credentials, eliminating long-lived credentials as the routine human access path.

Establishing the identity foundation in AWS has two components: how I manage human access and how I define the IAM baseline.  The deployment sequence also impacts what decisions may need to be revisited.

Human access is managed through Identity Center.  Its implementation relies on two difficult-to-change-later decisions: region and identity provider (IdP).  Since the service is region-specific, I need to intentionally select the region, since changing it later would require destroying the old instance and deploying a new one.  Second, I need to select an IdP.  Identity Center offers a built-in user directory, or I could connect to an external IdP, like Okta or Google SSO.

There are two elements defining the IAM baseline: emergency access and permission boundaries.  Often referred to as a "break-glass" identity, emergency access is for when the normal access path fails.  This could be an Identity Center misconfiguration, or a permission set provisioning failure.  It's rarely used, deliberately awkward, and triggers an alarm when invoked.  The failure mode I'm anticipating is if Identity Center is unreachable.  A role's trust policy has to name a principal to assume it.  If every human principal originates in Identity Center, and it's unavailable, then the principal is also unavailable.

Permission boundaries are like SCPs for principals.  They allow me to cap the maximum permissions allowed for a single principal, where permissions are determined by the intersection of boundaries and identity policies.  I could create permission boundaries first, but boundaries set against IAM users would need to be rewritten against permission set principals in Identity Center.  Additionally, break-glass trust design can't be finalized until I determine the human access path.

## Decision
I will use Identity Center for human access and deploy it before defining the IAM baseline.  It will be provisioned in `us-west-2`, since all of my current resources are located there.  I will use Identity Center's built-in directory as the identity provider, rather than taking on the cost of an external IdP.

> [!NOTE]
> Identity Center is enabled through the console, not a Terraform apply.  It doesn't change the impact of the decision, it's still a one-way-door, but it's otherwise transparent in the Terraform configuration.

The IAM baseline work will use Identity Center's permission sets to implement permission boundaries.

## Consequences
Provisioning Identity Center in `us-west-2` with the built-in IdP means that changing it later will be destructive and expensive.

The routine access path now depends on Identity Center, which is a service that may fail.  It moves the access control surface to directory operations: permission sets, assignments, and group membership.

The break-glass functionality needs to be verified through assumption to ensure it works as intended, and tested regularly.  

The `portfolio-admin` user can't be retired until the break-glass functionality is verified.

Retiring the `portfolio-admin` principal means I need to reevaluate how current and future Terraform executes, since it currently authenticates with a standing IAM user.


# notes
if my standard access path (IDC) is not available, the break_glass policy is dependent on what i'd need to do in an emergency in each individual account
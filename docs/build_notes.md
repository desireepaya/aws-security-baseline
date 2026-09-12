This document captures notes as I work through project phases, primarily unexpected gotchas and troubleshooting.  Entries are in reverse chronological order, newest first.  See [docs/adr](../docs/adr/) for architectural decisions.

> [!NOTE]
> **Phase 1 Findings:** Build notes for the first phase of this project live inline in the current README, pending extraction.

### 2026-SEP-11
Task summary:
- Finalized permission sets
- Configured Identity Center with groups, policy attachments
- Tested portal with new user
- `break_glass` design

AWS doesn't provide a managed policy for incident response or vulnerability remediation, which necessitates a design decision: create a customer-managed policy that allows Security Eng to escalate privileges beyond `SecurityAudit` to perform remediation.

Reviewed SCP attachment points: deny-IDC at root, CloudTrail tampering and region restriction at Workloads only.  Security Tooling isn't covered.

**Some surprises:**
Session duration format is different than expected.  It follows ISO 8601, requiring "PT" ahead of the time duration, "1H".

Using `depends_on` in the policy attachment resource to (need a better understanding here)

**Building out groups model:**
I started out thinking that my `test_user` would have standing read-only permissions by design, but as I worked through the group model, I ended with a validation instrument with no permissions at all.  That helped me build a mental model of how I want to test permissions going forward and removed the need to maintain a long-lived workforce user with no groups.

Given my past experience butting up against a lack of billing permissions in the past, I wanted to ensure `PlatformAdmins` were able to manage billing.  After researching its target permission set, I discovered that `AdministratorAccess` grants access to billing anyway, so that simplified its assignments.

I set the goal at the outset to use AWS-managed-policies only, since I didn't to manage custom policies as part of this project.  I ran into issues on three different occassions trying to refine access based on user persona that demonstrated the bar was pretty low for needing custom policies.  Tasks like incident response or vulnerability remediation would require finer-grained permissions that simply granting `AdministratorAccess` to the SecurityAnalysts group.  Walking through possible esclataion paths, I landed on assuming a different role to accomplish those tasks, similar to `sudo`.

The new terraform file applied cleanly and I saw the target accounts updated with the new groups.  I created a new workforce user and confirmed the portal was empty, as expected.

I added my new user to the `PlatformAdmins` group, logged out, back in, and the portal updated with the target accounts.

**In case of emergency...**
I scoped this initially thinking an IAM user would need broad permissions to fix multiple broken things, like a first responder.  In my permission sets sketch, it had its own column alongside the other IDC personas.  But working through the IDC design, it became clear that the `break_glass` user has a narrow definition: it needs to restore IDC access.  That can be done cleanly in the console, so it avoids generating long-lived programmatic credentials for this user.  It also points to two obvious detection patterns: `ConsoleLogin` and `AssumeRole`, since the user would be inert-at-rest and assume a role to do any fixing.

Narrowing the use case greatly simplified things, collapsing the design to a single account and one role.  This work lands in the next step, IAM baseline along with EventBridge detection.



### 2026-AUG-31
Task summary:
- Enabled Identity Center
- Updated SCPs to deny account-level instance creation

No Terraform resource exists to enable an org-level instance of Identity Center (IDC).  It's a gap in the Terraform provider, not a module gap.  It must be enabled from the console.  There is a `CreateInstance` API, but that creates an *account instance*, precisely what I don't want.

I documented the one-way-door decision in the [Identity Foundation ADR](../docs/adr/0003-identity-foundation.md), so enabling this in console meant ensuring I had the region set correctly (us-west-2).  The enablement page has a big banner at the top asking you to do as much.  Below that, it offers three options:
- Multi-region: sets us-west-2 as primary, and us-east-1 as the replication target
- Single region: us-west-2
- Custom region: us-west-2 as primary, choose additional region(s), but I'd need my own KMS key

Multi-region is overkill for my use case, is opinionated on its secondary region, and creates service redundancy that I can't leverage.  Custom region is similar, I get the flexibility of choosing the region, but I need to manually create and set my own KMS key.  Single region is the right fit for this project.

The region selection is fixed once I choose it, and the UI is clear that this is not a setting I can change later.  Once enabled, I'm dropped into the Overview page with a prominent Central Management tile that recommends the limitation of member accounts from creating their own IDC instances.  This isn't a service toggle, it's an update to SCPs.  An account-level instance circumvents the primary goal of enabling IDC, which is centralized control of external access.  Instead of configuring in console, I grabbed the recommended JSON, and shifted to my Terraform updates.

The current SCPs apply to my Workloads OU, restricting updates to CloudTrail and region availability.  I want the account-level instance restriction to apply to all OUs in the organization.  While updating [scps.tf](../terraform/org/scps.tf), I'm reminded that organization and root are different objects.  Org-level SCPs attach to the root via `aws_organizations_organization.this.roots[0].id`, not the org ID.  I then ran `terraform plan` expecting the creation of two new resources, but hold on...
``` bash
# aws_organizations_organization.this will be updated in-place
  ~ resource "aws_organizations_organization" "this" {
      ~ aws_service_access_principals = [
          - "sso.amazonaws.com",
    }
```
Enabling IDC in the console created an unexpected footgun: it mutated a resource managed by Terraform.  Terraform is trying to delete the service access principal that AWS added when I enabled IDC.  Naturally, it would want to delete something that didn't match the state it was expecting.  I updated [main.tf](../terraform/org/main.tf) to add `sso.amazonaws.com` to my trusted access list, and the change block cleared on the next plan run.

Any console action on a Terraform-managed resource will surface this type of drift on the next plan.  While general awareness of this relationship is good, it's better to practice the discipline of running plan after any console action before stacking further work on top of it.  This is where the Terraform investment pays off.

### 2026-AUG-19
Task summary:
- Delegated admin for Access Analyzer to Security Tooling account
- Enabled Access Analyzer

I began this exercise by replicating what I'd already done with GuardDuty: perform a two step process to delegate admin then configure the new service.  I added a resource block to [org/main.tf](../terraform/org/main.tf) using an AI-suggested resource name (`aws_accessanalyzer_organization_admin_account`), similar to the pattern I used for GuardDuty.  A Terraform plan returned this error:
``` bash
│ Error: Invalid resource type
│ 
│   on main.tf line 52, in resource "aws_accessanalyzer_organization_admin_account" "security_tooling":
│   52: resource "aws_accessanalyzer_organization_admin_account" "security_tooling" {
│ 
│ The provider hashicorp/aws does not support resource type "aws_accessanalyzer_organization_admin_account".
╵
```
Reviewing the Terraform provider docs confirmed that this resource doesn't exist.  Access Analyzer uses the generic `aws_organizations_delegated_administrator` instead.  I updated the resource entry and the plan and apply completed as expected.

Moving on to the service configuration, this resource type requires `analyzer_name` and `type` attributes.  I'd settled on a naming convention depending on how the name is used.  For HCL internal names, snake case is the common pattern.  For human-facing names, like those displayed in console, I find title case easier to read.  I chose explicitly not to use Pascal case because I find it difficult to read.  That approach failed me in this case.  When I tried to run a plan against the `analyzer_name = "Org External Access Analyzer"` I got this error:
``` bash
│ Error: invalid value for analyzer_name (must begin with a letter and contain only alphanumeric, underscore, period, or hyphen characters)
```
This attribute doesn't support title case.  I changed it to `org_external_access_analyzer` and plan completed successfully.

Running an apply took longer than expected and returned this error:
``` bash
│ Error: creating IAM Access Analyzer Analyzer (org_external_access_analyzer): operation error AccessAnalyzer: CreateAnalyzer, https response error StatusCode: 409, RequestID: 2d079626-195a-4676-964e-4cfba4286f77, ConflictException: Access Analyzer Service Linked Role is not in the organizational management account
```
My first thought was that this might be a propagation delay, since I'd recently created the delegated admin resource.  But looking closer at the error, it says the service linked role is missing from the management account.  The generic delegated admin resource doesn't provision the service-linked account automatically.

I provisioned a service-linked role for Access Analyzer in org/main.tf, then the plan/apply for the service configuration completed successfully.

**Interesting snag:** GuardDuty's `admin_account` resource doesn't require an explicit service-linked-role resource, so the error provisioning a similar resource for Access Analyzer was unexpected.

**Finding:** verify AI-suggested resources names against the provider docs before applying.  This is the second occurrence in this project.

### 2026-AUG-18
Task summary:
- Created new security OU and tooling account
- Created new Terraform directory for security-tooling, with separate provider and backend
- Enabled GuardDuty detector and auto-enrolled new accounts

Delegation calls come from the management account [org/main.tf](../terraform/org/main.tf).
Service configuration happens in the security-tooling account [security-tooling/main.tf](../terraform/security-tooling/main.tf) 

**Interesting snag:** first Terraform apply from the `security-tooling` directory errored out with "detector already exists":
``` bash
│ Error: creating GuardDuty Detector: operation error GuardDuty: CreateDetector, https response error StatusCode: 400, RequestID: e96c07ac-b22f-468c-a660-5c5ae3228b55, BadRequestException: The request is rejected because a detector already exists for the current account.
```

My first thought was region mismatch, maybe it was defaulting to us-east-1 instead of us-west-2.  A run of list-detectors came back empty.  The query was running with the default profile credentials.  I'd created the new security-tooling account shortly before this, but failed to update my profile to include it.  I updated `~/.aws/credentials` with the new profile for security-tooling; `list-detectors` run with the new profile returned a detector ID.

Apparently, new accounts get a 30-day detector trial when the service is first enabled.  Rather than delete and reprovision, I updated [security-tooling/main.tf](../terraform/security-tooling/main.tf) to import the existing detector and reran apply.

**Finding:** the pattern of new security-tooling account creation and GuardDuty configuration will be common when standing up new organizations.  Updating credentials profiles should be muscle memory.
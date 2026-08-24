This document captures notes as I work through project phases, primarily unexpected gotchas and troubleshooting.  Entries are in reverse chronological order, newest first.  See [docs/adr](../docs/adr/) for architectural decisions.

> [!NOTE]
> **Phase 1 Findings:** Build notes for the first phase of this project live inline in the current README, pending extraction.

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
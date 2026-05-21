> [!NOTE]
> STATUS: Phase 1 build in progress.\
> Infrastructure deploys targeted for Friday, May 22; documentation sections populate as the build progresses.

# AWS Security Baseline & Guardrail Architecture

A multi-account AWS Organization implementing security guardrails: SCPs, centralized logging, and (in Phase 2) detection services with delegated administration.

This treats security as reliability.  Controls are preventative wherever possible, detective where necessary, and deferred where they would generate unactionable noise or cost.

## Architecture
![Architecture](docs/images/guardrail_scope_diagram.png)

## Scope
### Phase 1
- AWS Organization with management account and one workload account
- One Workloads OU
- Service Control Policies applied at the OU level
- Organization-level CloudTrail trail
- KMS-encrypted S3 bucket for log storage
- Terraform with remote state

### Phase 2
- Identity Center for human access, with permission sets
- GuardDuty with delegated administration
- AWS Config with organization aggregator
- IAM Access Analyzer at the organization level
- IAM baseline (break-glass role, baseline permission boundaries)

### Deliberately deferred
**Security Hub** -- Aggregates findings from GuardDuty, Config, and Access Analyzer.  Aggregation has no value without a triage and remediation workflow.  Absent that workflow, Security Hub is a second dashboard producing the same findings surfaced elsewhere, at an additional cost.  Deferring to the Automated Remediation Pipeline project, where it connects detection and automated response.

**WAF, Shield Advanced, Network Firewall** -- Advanced controls not justified by this portfolio's threat model.

## Design decisions
**Identity Center with built-in directory**

Alternatives considered: IAM users per account, Identity Center federated to an external IdP.

Chose Identity Center with the built-in directory because IAM users in each account create credential sprawl that doesn't scale beyond two or three accounts.  An external IdP adds infrastructure complexity and cost that are not justified for an environment with one human user.  Identity Center centralizes human access at the org level and lets permission sets be assigned to accounts, which is the pattern that would extend cleanly to a production environment.

**DynamoDB lock table for state locking**

Alternatives considered: Newer versions of Terraform support native S3-based locking with `use_lockfile`, replacing the use of DynamoDB.  Chose to keep the DynamoDB pattern because it matches what production environments likely run today while demonstrating the distributed-systems reasoning behind state locking.  A future upgrade would migrate to `use_lockfile` and decommission the DynamoDB table.
## How this was built

## Reproducing this environment

## Repo structure

 

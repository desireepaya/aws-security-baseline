# AWS Security Baseline & Guardrail Architecture

A mutli-account AWS Organization implementing security guardrails: SCPs, centralized logging, and (in Week 2) detection services with delegated administration.

This treats security as reliability.  Controls are preventative wherever possible, detective where necessary, and deferred where they would generate unactionable noise or cost.

## Architecture
<img width="816" height="680" alt="guardrail_scope_diagram" src="https://github.com/user-attachments/assets/15b03698-3dab-43aa-bc94-72c2a2ab342e" />

## Scope
### Week 1
- AWS Organization with management account and one workload account
- One Workloads OU
- Service Control Policies applied at the OU level
- Organization-level CloudTrail trail
- KMS-encrypted S3 bucket for log storage
- Terraform with remote state

### Week 2
- Identity Center for human access, with permission sets
- GuardDuty with delegated administration
- AWS Config with organization aggregator
- IAM Access Analyzer at the organization level
- IAM baseline (break-glass role, baseline permission boundaries)

### Deliberately deferred
**Security Hub** -- Aggregates findings from GuardDuty, Config, and Access Analyzer.  Aggregation has no value without a triage and remediation workflow.  Absent that workflow, Security Hub is a second dashboard producing the same findings surfaced elsewhere, at an additional cost.  Deferring to the Automated Remediation Pipeline project, where it connects detection and automated response.

**WAF, Shield Advanced, Network Firewall** -- Advanced controls not justified by this portfolio's threat model.

## Design decisions

## How this was built

## Reproducing this environment

## Repo structure
 

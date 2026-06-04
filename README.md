> [!NOTE]
> **Status**: Phase 1 build complete

# AWS Security Baseline & Guardrail Architecture

A multi-account AWS Organization implementing security guardrails: SCPs, centralized logging, and (in Phase 2) detection services with delegated administration.

This treats security as reliability.  Controls are preventative wherever possible, detective where necessary, and deferred where they would generate noise without a remediation path.

## Architecture
![Architecture](docs/images/guardrail_scope_diagram.png)

## Scope
### Phase 1
#### Shipped
- AWS Organization with management account and one workload account
- One Workloads OU
- Terraform with remote state
- Service Control Policies applied at the OU level
- KMS-encrypted S3 bucket for log storage
- Organization-level CloudTrail trail

#### Phase 1 governance layer
The focus of this section was establishing a secure foundation for this environment.  With the completion of SCP, KMS, and S3 work, I now have the preventative controls in place at the organization level.
What this enables:
- **Region containment:** Prevents access or provisioning of resources outside of the target region.
- **CloudTrail protection:** An SCP prevents member accounts from disabling or deleting CloudTrail, protecting the org trail once it's deployed.
- **Storage hardened for the org trail:** KMS encryption at rest, bucket versioning, and ownership enforcement maintain log integrity once logs flow.
- **Verified controls:** Each control was verified against its intended behavior using a documented test matrix.

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

Chose Identity Center with the built-in directory because IAM users in each account create credential sprawl that doesn't scale beyond two or three accounts.  An external IdP adds infrastructure complexity and cost that are not justified for an environment with one human user.  Identity Center centralizes human access at the org level and lets permission sets be assigned to accounts, which is the pattern that would extend cleanly to a production environment.  This work lands in Phase 2.

**DynamoDB lock table for state locking**

Alternatives considered: Newer versions of Terraform support native S3-based locking with `use_lockfile`, replacing the use of DynamoDB.

Chose to keep the DynamoDB pattern because it matches what production environments likely run today while demonstrating the distributed-systems reasoning behind state locking.  A future upgrade would migrate to `use_lockfile` and decommission the DynamoDB table.

## How this was built
### Environment bootstrap

Before I could create any organization-level resources, Terraform needed somewhere to write state, ideally with locking to prevent concurrent runs from corrupting it.  This creates a chicken-and-egg problem: the standard pattern is remote state in S3 with a DynamoDB lock table.  With a new environment, those resources don't yet exist and Terraform won't init against a bucket it can't reach.

I solved it by writing the bootstrap config with no backend block, defaulting to local state on disk.  The first apply created the S3 bucket and DynamoDB table.  I then added the backend configuration and reran `terraform init`.  Terraform detected the new backend and prompted for migration.  From that point, it manages its own state from inside the infrastructure it provisions.  Creating these resources from console would have been faster, but would have broken the IaC pattern this project depends on.

One deferred decision worth mentioning: Terraform recently introduced native S3 locking with `use_lockfile`, deprecating the DynamoDB approach.  I kept DynamoDB because it matches what many production environments likely run and demonstrates the distributed-systems reasoning behind state locking.

For authentication during the bootstrap phase, I created an IAM user with scoped admin permissions to the sandbox account.  Identity Center is the production pattern and is scoped for Phase 2.  It requires the organization management account to exist first, which is the bootstrap work of Phase 1.

With state management and authentication in place, the next step creates the AWS Organization itself.

### AWS Organization

I decided to use an organizational unit (OU) because I wanted this project to demonstrate production patterns.  The work to attach SCPs to a single-account OU is the same as an OU with dozens of accounts, and this approach builds that muscle memory.

I also created a separate sandbox account for running workloads instead of having them run in the management account.  This might seem like unnecessary overhead, but that obscures two important implementation details.  First, SCPs don't apply to the management account, so I'd need a separate account to demonstrate SCP attachment anyway.  Second, the management account is for org administration, not workloads.  Running workloads there creates a blast-radius problem, where a compromised workload would threaten org administration itself.

Here is the final state after applying all changes in Terraform:

![Organizations console screenshot](docs/images/organizations-console.png)

### Organization-level Logging
The last piece to pull all this foundational work together was implementing CloudTrail at the organization level.  This captures logs for both the admin and member accounts and is the prerequisite for implementing detective controls.  Testing the trail end-to-end was the final validation of the infrastructure and preventative controls.

## Reproducing this environment

### Establish credentials
You will need an initial set of credentials to start.  Creating a new account with AWS is straight-forward.
- Follow the setup instructions on [AWS's website](https://aws.amazon.com/).
- Create an IAM user with admin permissions.
- Add the IAM admin user credentials to your local AWS config.  This is your management profile.

### Bootstrap local state then migrate to remote backend
Terraform will need to write to a local state file initially.  
- Bootstrap the environment with an S3 bucket and a DynamoDB table.
- Once both resources exist, add a `backend` block to `providers.tf`.  See [note](terraform/bootstrap/providers.tf) for build sequence.
- Rerun `terraform init` and it should pick up the remote backend.

### Build organization resources
These configurations are established in a separate `org/` module.
- Create the organization, OU, SCPs, sandbox (member) account.
- Note: the sandbox account requires a unique email address.  
- Create a sandbox profile in your local AWS config with the new credentials.  The second profile is used during validation testing.

>[!WARNING]
>An AWS account doesn't fully delete on `terraform destroy`.  It's marked for deletion after a delay.  This impacts what email you used to create the account, since it can't be immediately reused.

### Verification
- Testing steps are documented in [Verification](docs/verification.md).
- Note: when testing Insecure Transport (Test 5.4), `InvalidArgument` is an expected result.  KMS's default TLS enforcement makes it difficult to cleanly isolate a denial from the bucket policy.

## Repo structure
  ```bash
  ├── aws-security-baseline
  │   ├── docs
  │   │   ├── images
  │   │   │   ├── guardrail_scope_diagram.png
  │   │   │   └── organizations-console.png
  │   │   ├── outputs-phase1.txt
  │   │   └── verification.md
  │   ├── LICENSE
  │   ├── README.md
  │   └── terraform
  │       ├── bootstrap
  │       │   ├── main.tf
  │       │   ├── outputs.tf
  │       │   └── providers.tf
  │       └── org
  │           ├── cloudtrail.tf
  │           ├── kms.tf
  │           ├── main.tf
  │           ├── outputs.tf
  │           ├── policies
  │           │   ├── cloudtrail_kms_key.json.tpl
  │           │   ├── cloudtrail_s3_bucket_policy.json.tpl
  │           │   ├── deny_cloudtrail_tampering.json
  │           │   └── restrict_regions.json
  │           ├── providers.tf
  │           ├── s3.tf
  │           └── scps.tf

# Verification
This test plan documents how to verify the controls I implemented for SCPs, KMS, S3, and CloudTrail in Phase 1 of this project.  I will run it after I've deployed these resources via Terraform.

## Approach
I chose to keep these tests manual, instead of a test harness or automation.  For a single sandbox environment with one-time validation, manual testing is the right-sized solution since the test matrix is only completed once.  If this were a production environment with continuous deployment, the same test matrix would leverage a resource like Terratest or CI-driven policy checks.  The verification logic is the same, but the harness changes.

## Prerequisites
This verification process assumes two configured profiles:
- `portfolio` : linked to an IAM user with admin access to the management account (portfolio-admin)
- `sandbox`: role assumption profile for `OrganizationAccountAccessRole` in the sandbox account, uses `portfolio` as the source profile

Configuration in `~/.aws/config`:
  ```ini
  [profile sandbox]
  role_arn = arn:aws:iam::SANDBOX_ACCOUNT_ID:role/OrganizationAccountAccessRole
  source_profile = portfolio
  region = us-west-2
  ```
*Replace `SANDBOX_ACCOUNT_ID` with the 12-digit account number of your sandbox account, found via console or by running:*
  ```bash
  aws organizations list-accounts --profile portfolio
  ```
Verify the management account can assume the admin role in the sandbox account by running the following command.  It should return a JSON blob with the assumed role ARN.
  ```bash
  aws sts get-caller-identity --profile sandbox
  ```
## Test matrix

### SCP: Deny CloudTrail tampering

**Test 1.1: Sandbox cannot stop the org trail**
- **Control:** SCP — Deny CloudTrail tampering
- **Test action:** Sandbox attempts to stop the org trail.
  ```bash
  aws cloudtrail stop-logging --name portfolio-org-trail --profile sandbox
  ```
- **Expected:** AccessDeniedException with "explicit deny in a service control policy"
- **Actual:** :white_check_mark:
  ```bash
  User: arn:aws:sts::560628764625:assumed-role/OrganizationAccountAccessRole/botocore-session-1780083349 is not authorized to perform: cloudtrail:StopLogging on resource: arn:aws:cloudtrail:us-west-2:560628764625:trail/portfolio-org-trail with an explicit deny in a service control policy...
  ```
> [!TIP]
> The SCP fired despite the target trail not existing yet.  This confirms SCPs are evaluated at authorization before resource lookup.

**Test 1.2: Sandbox cannot create a trail**
- **Control:** SCP - Deny CloudTrail tampering
- **Test action:** Sandbox attempts to create a trail.
  ```bash
  aws cloudtrail create-trail --name scp-test-trail --s3-bucket-name fake-bucket678 --profile sandbox
  ```
- **Expected:** AccessDeniedException with "explicit deny in a service control policy"
- **Actual:** :white_check_mark:
  ```bash
  User: arn:aws:sts::560628764625:assumed-role/OrganizationAccountAccessRole/botocore-session-1780083349 is not authorized to perform: cloudtrail:CreateTrail on resource: arn:aws:cloudtrail:us-west-2:560628764625:trail/scp-test-trail with an explicit deny in a service control policy...
  ```
> [!TIP]
> Same principle here: I used a placeholder bucket name to satisfy the required parameters; SCP still fired ahead of validating the bucket.

**Test 1.3: Sandbox can perform CloudTrail read operations (negative over-deny test)**
- **Control:** SCP - Deny CloudTrail tampering
- **Test action:** Sandbox attempts to read a trail.
  ```bash
  aws cloudtrail describe-trails --trail-name-list portfolio-org-trail --profile sandbox
  ```
- **Expected:** Success, command returns trail.
- **Actual:** [deferred -- requires a valid trail]

**Test 1.4: Management account attempts to stop logging**
- **Control:** SCP - Deny CloudTrail tampering
- **Test action:** Management account attempts to stop logging on a non-existent trail.
  ```bash
  aws cloudtrail stop-logging --name fake-org-trail --profile portfolio
  ```
- **Expected:** Success, SCP authorizes, but trail not found.
- **Actual:** :white_check_mark:
  ```bash
  aws: [ERROR]: An error occurred (TrailNotFoundException) when calling the StopLogging operation: Unknown trail...
  ```

### SCP: Region restriction
**Test 2.1: Sandbox calls a service in us-west-2**
- **Control:** SCP - Restrict Regions
- **Test action:** Sandbox account attempts to list EC2 instances in us-west-2.
  ```bash
  aws ec2 describe-instances --region us-west-2 --profile sandbox
  ```
- **Expected:** Success -- command returns Reservation list (empty if no instances provisioned).  Either result proves SCP allowed the action.
- **Actual:** :white_check_mark: Success, returned empty list

**Test 2.2: Sandbox calls the same service in us-east-1**
- **Control:** SCP - Restrict Regions
- **Test action:** Sandbox account attempts to list EC2 instances in us-east-1.
  ```bash
  aws ec2 describe-instances --region us-east-1 --profile sandbox
  ```
- **Expected:** AccessDeniedException with "explicit deny in a service control policy"
- **Actual:** :white_check_mark:
  ```bash
  User: arn:aws:sts::560628764625:assumed-role/OrganizationAccountAccessRole/botocore-session-1780083349 is not authorized to perform: ec2:DescribeInstances with an explicit deny in a service control policy...
  ```

**Test 2.3: Sandbox calls IAM (global service in `NotAction` list)**
- **Control:** SCP - Restrict Regions
- **Test action:** Sandbox account attempts to list roles.
  ```bash
  aws iam list-roles --profile sandbox
  ```
- **Expected:** Success -- command returns JSON of roles in Sandbox account.
- **Actual:** :white_check_mark: Success -- returned valid JSON list of roles.

**Test 2.4: Sandbox calls STS in any region (in `NotAction` list)**
- **Control:** SCP - Restrict Regions
- **Test action:** Sandbox user attempts to call STS in us-east-1.
  ```bash
  aws sts get-caller-identity --region us-east-1 --profile sandbox
  ```
- **Expected:** Success -- command returns JSON of current user.
- **Actual:** :white_check_mark: Success -- returned valid JSON for AssumedRole

**Test 2.5: Sandbox calls CloudFront in us-east-1 (`NotAction` validation, negative)**
- **Control:** SCP - Restrict Regions
- **Test action:** Sandbox account attempts to list CloudFront distributions in us-east-1.
  ```bash
  aws cloudfront list-distributions --region us-east-1 --profile sandbox
  ```
- **Expected:** AccessDeniedException with "explicit deny in a service control policy"
- **Actual:** :white_check_mark:
  ```bash
  User: arn:aws:sts::560628764625:assumed-role/OrganizationAccountAccessRole/botocore-session-1780083349 is not authorized to perform: cloudfront:ListDistributions with an explicit deny in a service control policy...
  ```

### KMS key + policy
**Test 3.1: Confirm KMS key exists**
- **Control:** KMS Enabled for CloudTrail
- **Test action:** Management account queries key state.
  ```bash
  aws kms describe-key --key-id alias/cloudtrail-org-trail --profile portfolio
  ```
- **Expected:** Returns key metadata, `KeyId`, `KeyState: Enabled`, `KeyManager: CUSTOMER`, description matches Terraform.
- **Actual:** :white_check_mark: Metadata includes expected values.
  ```bash
          "KeyId": "3ce9748a-ecd9-46da-9c3c-2a5eca5496fd",
          "KeyState": "Enabled",
          "KeyManager": "CUSTOMER",
          "Description": "KMS key for encrypting organization logs",
```

**Test 3.2: Confirm alias points to the right key**
- **Control:** KMS Enabled for CloudTrail
- **Test action:** Management account queries available aliases.
  ```bash
  aws kms list-aliases --profile portfolio | grep -A 2 cloudtrail-org-trail
  ```
- **Expected:** Returns key metadata, `TargetKeyId` matches output from Test 3.1.
- **Actual:** :white_check_mark: Alias returned, `TargetKeyId` matches `KeyId` from Test 3.1.
  ```bash
  "TargetKeyId": "3ce9748a-ecd9-46da-9c3c-2a5eca5496fd",
  ```

**Test 3.3: Confirm the key policy**
- **Control:** KMS Enabled for CloudTrail
- **Test action:** Management account confirms key policy is populated with actual ARN values.
  ```bash
  aws kms get-key-policy --key-id [KeyId from Test 3.1] --policy-name default --profile portfolio
  ```
- **Expected:** Returns the policy JSON with `aws:SourceArn` and `kms:EncryptionContext` rendering actual ARN instead of variable placeholder.
- **Actual:** :white_check_mark: Both values rendered as expected.
  ```bash
  "aws:SourceArn\" : \"arn:aws:cloudtrail:us-west-2:933613018572:trail/portfolio-org-trail\",\n        \"kms:EncryptionContext:aws:cloudtrail:arn\" : \"arn:aws:cloudtrail:us-west-2:933613018572:trail/portfolio-org-trail\
  ```

**Test 3.4: Confirm rotation is enabled**
- **Control:** KMS Enabled for CloudTrail
- **Test action:** Management account queries key rotation status.
  ```bash
  aws kms get-key-rotation-status --key-id [KeyId from Test 3.1] --profile portfolio
  ```
- **Expected:** Returns key metadata, `KeyRotationEnabled: true`.
- **Actual:** :white_check_mark: `KeyRotationEnabled` returned the expected value.
  ```bash
  "KeyRotationEnabled": true,
  ```

### S3 bucket + policy
**Test 4.1: Bucket uses KMS to encrypt bucket**
- **Control:** S3 Encryption at Rest
- **Test action:** Management account confirms bucket settings.
  ```bash
  aws s3api get-bucket-encryption --bucket dp-cloudtrail-logs-933613018572 --profile portfolio
  ```
- **Expected:** Returns encryption type with the correct ARN.
- **Actual:** :white_check_mark: Confirmed SSE configuration with expected ARN
  ```bash
  "ApplyServerSideEncryptionByDefault": {
    "SSEAlgorithm": "aws:kms",
    "KMSMasterKeyID": "arn:aws:kms:us-west-2:933613018572:key/3ce9748a-ecd9-46da-9c3c-2a5eca5496fd"
    }
  ```

**Test 4.2: Public access is blocked**
- **Control:** S3 Block Public Access
- **Test action:** Management account confirms Public Access Block configuration.
  ```bash
  aws s3api get-public-access-block --bucket dp-cloudtrail-logs-933613018572 --profile portfolio
  ```
- **Expected:** Returns `block_public_acls`, `block_public_policy`, `ignore_public_acls`, and `restrict_public_buckets` all `true`. 
- **Actual:** :white_check_mark: All values returned `true`.
  ```bash
   "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
  ```

**Test 4.3: Enforce BucketOwner ownership**
- **Control:** S3 Object Ownership
- **Test action:** Management account confirms bucket ownership enforcement.
  ```bash
  aws s3api get-bucket-ownership-controls --bucket dp-cloudtrail-logs-933613018572 --profile portfolio
  ```
- **Expected:** Returns `BucketOwnerEnforced`.
- **Actual:** :white_check_mark: Returned expected value.
  ```bash
  "Rules": [
      {
        "ObjectOwnership": "BucketOwnerEnforced"
      }
  ```

**Test 4.4: Bucket versioning is enabled**
- **Control:** S3 Versioning
- **Test action:** Management account confirms versioning settings.
  ```bash
  aws s3api get-bucket-versioning --bucket dp-cloudtrail-logs-933613018572 --profile portfolio
  ```
- **Expected:** Returns `Status: Enabled`.
- **Actual:** :white_check_mark: Expected value returned.
```bash
"Status": "Enabled"
```

**Test 4.5: Confirm CloudTrail write access**
- **Control:** S3 BucketPolicy
- **Test action:** Management account confirms policy variables rendered as expected.
  ```bash
  aws s3api get-bucket-policy --bucket dp-cloudtrail-logs-933613018572 --profile portfolio
  ```
- **Expected:** Three statements (`CloudTrailGetBucketAcl`, `CloudTrailPutObject`, `DenyInsecureTransport`) with ARNs rendered.
- **Actual:** :white_check_box: Three statements present. All three template variables rendered correctly: bucket_arn, org_id as o-60rf2ejetx in PutObject path, trail_arn in both SourceArn conditions.

### CloudTrail trail (end-to-end)
**Test .: **
- **Control:** 
- **Test action:** 
  ```bash
  
  ```
- **Expected:** 
- **Actual:** [TBD]

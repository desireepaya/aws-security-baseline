# ADR-0006: Terraform Uses IDC SSO Session
Status: Accepted

Date: 2026-OCT-1

## Context
This project was bootstrapped with an IAM user ahead of implementing IAM Identity Center (IDC).  Now that IDC is live and the human path verified, it's time to update Terraform to use it, eliminating the known risk of a long-lived key with admin privileges [ADR-0003: Identity Foundation](./0003-identity-foundation.md).  This work was pulled forward due to a workstation upgrade.

## Decision
Terraform runs under a human IDC SSO session assuming the `PlatformAdmin` permission set in the management account.  SSO provides short-lived credentials, so there's no key to rotate and no key to leak, and CloudTrail shows the named human behind every apply.  Terraform actions no longer rely on the `portfolio-admin` key.

## Consequences
The `portfolio-admin` user has no remaining dependencies and gets deleted.  Any Terraform apply requires a human in the loop until a pipeline identity exists, and is bounded by the permission set's session duration.
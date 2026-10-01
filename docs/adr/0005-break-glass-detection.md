# ADR-0005: Break-glass Detection
Status: Accepted

Date: 2026-OCT-1

## Context
A break-glass role exists in this environment, which creates a risk for misuse.  Since the permissions are broad by choice, I want to trigger an alert every time the role is assumed.  There are two possible events to match on: `SwitchRole` and `AssumeRole`.

## Decision
Trigger the alert off of the STS `AssumeRole` event, since it will catch both console role switching and CLI or SDK assumptions.  `SwitchRole` only covers assumptions through the console.  The EventBridge rule matches only when the target role is `break_glass_admin_role`, using the role ARN from `requestParameters`.

## Consequences
This method alerts on successful assumption only.  On a [denied `AssumeRole`](../build_notes.md#2026-sep-30), CloudTrail records the `requestParameters` field as null, so the role ARN match never fires.  The rule has no explicit filter on `errorCode`, so no alert is the consequence of how CloudTrail records the denial rather than a condition in the pattern.  A failed-attempt detection would need a different key, `userIdentity.userName` plus `errorCode`.
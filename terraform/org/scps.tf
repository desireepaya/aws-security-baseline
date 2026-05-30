# 1. SCP to restrict regions to us-west-2.
resource "aws_organizations_policy" "restrict_regions" {
  name        = "RestrictRegions"
  description = "Deny access to all regions except for us-west-2."
  content     = file("${path.module}/policies/restrict_regions.json")
  type        = "SERVICE_CONTROL_POLICY"
}
resource "aws_organizations_policy_attachment" "restrict_regions_attachment" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = aws_organizations_organizational_unit.workloads.id
}
# 2. SCP to deny CloudTrail tampering.
resource "aws_organizations_policy" "deny_cloudtrail_tampering" {
  name        = "DenyCloudTrailTampering"
  description = "Deny CloudTrail tampering attempts against org trail."
  content     = file("${path.module}/policies/deny_cloudtrail_tampering.json")
  type        = "SERVICE_CONTROL_POLICY"
}
resource "aws_organizations_policy_attachment" "deny_cloudtrail_tampering_attachment" {
  policy_id = aws_organizations_policy.deny_cloudtrail_tampering.id
  target_id = aws_organizations_organizational_unit.workloads.id
}
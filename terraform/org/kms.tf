data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Construct the trail ARN manually from known values to prevent
# a circular dependency between the trail and the KMS key policy.
locals {
  trail_arn = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/portfolio-org-trail"
}
# Renamed trail key after provisioning due to ambiguity it caused in s3 config.
moved {
  from = aws_kms_key.cloudtrail_org_trail
  to   = aws_kms_key.cloudtrail_org_trail_key
}

# KMS key for encrypting organization logs.
resource "aws_kms_key" "cloudtrail_org_trail_key" {
  description             = "KMS key for encrypting organization logs"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = templatefile("${path.module}/policies/cloudtrail_kms_key.json.tpl", {
    trail_arn = local.trail_arn
  })
}
# Rename resource identifier to match KMS key rename.
moved {
  from = aws_kms_alias.cloudtrail_org_trail
  to   = aws_kms_alias.cloudtrail_org_trail_key
}
# Set alias for KMS key for easier console use.
resource "aws_kms_alias" "cloudtrail_org_trail_key" {
  name          = "alias/cloudtrail-org-trail"
  target_key_id = aws_kms_key.cloudtrail_org_trail_key.key_id
}
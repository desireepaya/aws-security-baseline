# create the trail: reference resources already created; depends on the s3 bucket policy
resource "aws_cloudtrail" "portfolio_org_trail" {
  name                          = "portfolio-org-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_org_logs.id
  kms_key_id                    = aws_kms_key.cloudtrail_org_trail_key.arn
  is_organization_trail         = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  depends_on                    = [aws_s3_bucket_policy.allow_cloudtrail_bucket_access]
}
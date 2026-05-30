# data already declared in kms.tf
# has a name
resource "aws_s3_bucket" "cloudtrail_org_logs" {
  bucket = "dp-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  # won't get deleted by accident
  lifecycle {
    prevent_destroy = true
  }
}
# attach bucket policy
resource "aws_s3_bucket_policy" "allow_cloudtrail_bucket_access" {
  bucket = aws_s3_bucket.cloudtrail_org_logs.id
  policy = templatefile("${path.module}/policies/cloudtrail_s3_bucket_policy.json.tpl", {
    bucket_arn = aws_s3_bucket.cloudtrail_org_logs.arn
    trail_arn  = local.trail_arn
    org_id     = aws_organizations_organization.this.id
  })
}
# is encrypted
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_org_logs" {
  bucket = aws_s3_bucket.cloudtrail_org_logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cloudtrail_org_trail_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
# bucket isn't publicly accessible
resource "aws_s3_bucket_public_access_block" "cloudtrail_org_logs" {
  bucket = aws_s3_bucket.cloudtrail_org_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
# has versioning enabled
resource "aws_s3_bucket_versioning" "cloudtrail_org_logs" {
  bucket = aws_s3_bucket.cloudtrail_org_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}
# enforces bucket owner ownership of files
resource "aws_s3_bucket_ownership_controls" "cloudtrail_org_logs" {
  bucket = aws_s3_bucket.cloudtrail_org_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
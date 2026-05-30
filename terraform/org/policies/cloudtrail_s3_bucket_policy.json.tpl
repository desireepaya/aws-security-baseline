{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudTrailGetBucketAcl",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "${bucket_arn}",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "${trail_arn}"
        }
      }
    },
    {
      "Sid": "CloudTrailPutObject",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "${bucket_arn}/AWSLogs/${org_id}/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "${trail_arn}",
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "${bucket_arn}",
        "${bucket_arn}/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
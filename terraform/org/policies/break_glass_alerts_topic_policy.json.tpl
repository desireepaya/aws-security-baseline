{
    "Version": "2012-10-17",
    "Statement": [
    {
      "Sid": "AllowPublishBreakGlassEvents",
      "Effect": "Allow",
      "Principal": {"Service": "events.amazonaws.com"},
      "Action": [
        "sns:Publish"
      ],
      "Resource": [
        "${topic_arn}"
      ],
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "${rule_arn}"
        }
      }
    }
  ]
}
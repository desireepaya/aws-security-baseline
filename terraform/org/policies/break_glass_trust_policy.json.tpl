{
    "Version": "2012-10-17",
    "Statement": [
    {
      "Sid": "AllowAssumeRoleBreakGlass",
      "Effect": "Allow",
      "Principal": {"AWS": "${break_glass_arn}"},
      "Action": [
        "sts:AssumeRole"
      ],
      "Condition": {
        "Bool": {"aws:MultiFactorAuthPresent": "true"}
      }
    }
  ]
}
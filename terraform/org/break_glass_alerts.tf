resource "aws_sns_topic" "break_glass_alerts" {
  name = "break_glass_alerts"
}

resource "aws_sns_topic_policy" "break_glass_alerts_policy" {
  arn = aws_sns_topic.break_glass_alerts.arn
  policy = templatefile("${path.module}/policies/break_glass_alerts_topic_policy.json.tpl", {
    topic_arn = aws_sns_topic.break_glass_alerts.arn
    rule_arn  = aws_cloudwatch_event_rule.break_glass_assume_role.arn
  })
}

resource "aws_cloudwatch_event_rule" "break_glass_assume_role" {
  name        = "break_glass_assume_role"
  description = "Event rule that alerts on assumption of emergency role"
  event_pattern = templatefile("${path.module}/policies/break_glass_assume_role_pattern.json.tpl", {
    break_glass_role_arn = aws_iam_role.break_glass_admin_role.arn
  })
}

resource "aws_cloudwatch_event_target" "break_glass_alert_target" {
  rule = aws_cloudwatch_event_rule.break_glass_assume_role.name
  arn  = aws_sns_topic.break_glass_alerts.arn
  input_transformer {
    input_paths = {
      time = "$.detail.eventTime"
      user = "$.detail.userIdentity.userName"
      role = "$.detail.requestParameters.roleArn"
      mfa  = "$.detail.userIdentity.sessionContext.attributes.mfaAuthenticated"
      ip   = "$.detail.sourceIPAddress"
    }
    input_template = "\"<role> was assumed by <user> at <time> from <ip>. MFA present: <mfa> || Expected: source AWS Internal (console), MFA true.  Anything else is anomalous.\""
  }
}

resource "aws_sns_topic_subscription" "break_glass_alert_subscription" {
  topic_arn = aws_sns_topic.break_glass_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_endpoint
}

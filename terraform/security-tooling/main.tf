resource "aws_guardduty_detector" "main" {
  enable = true
}
import {
  to = aws_guardduty_detector.main
  id = "24d00b76e49c10afa839d90d7a1a21d6"
}

resource "aws_guardduty_organization_configuration" "main" {
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.main.id

  datasources {
    # Setting these to false ensures sub-features are off by design
    # TODO a future revision could migrate to a newer per-feature resource model
    s3_logs {
      auto_enable = false
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = false
        }
      }
    }
  }
}

resource "aws_accessanalyzer_analyzer" "external_access" {
  analyzer_name = "org_external_access_analyzer"
  type          = "ORGANIZATION"
}

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "dp-tfstate-aws-security-baseline"
    key            = "security-tooling/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "tf-lock-aws-security-baseline"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.security_tooling_account_id}:role/OrganizationAccountAccessRole"
  }
}
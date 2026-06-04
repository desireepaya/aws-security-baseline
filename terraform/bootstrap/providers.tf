terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }

  # NOTE: this backend block was added AFTER the initial bootstrap apply.
  # On a clean rebuild, comment this out, apply to create the bucket and 
  # DynamoDB table with local state.  Then uncomment and run `terraform init`
  # to migrate state to the remote backend.  See README "Reproducing this environment".
  backend "s3" {
    bucket         = "dp-tfstate-aws-security-baseline"
    key            = "bootstrap/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "tf-lock-aws-security-baseline"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-west-2"
}
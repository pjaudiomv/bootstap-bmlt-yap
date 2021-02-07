terraform {
  required_version = ">= 0.14"

  backend "s3" {
    bucket         = "tomato-terraform-state-patrick"
    region         = "us-east-1"
    dynamodb_table = "pj-sand-lock-tbl"
    key            = "bmlt-bs/terraform.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

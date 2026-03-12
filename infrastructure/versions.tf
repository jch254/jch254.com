terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "jch254-terraform-remote-state"
    key     = "jch254dotcom-prod-infrastructure"
    region  = "ap-southeast-4"
    encrypt = true
  }
}
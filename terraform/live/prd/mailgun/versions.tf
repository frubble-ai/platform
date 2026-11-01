terraform {
  required_version = ">= 1.13"

  required_providers {
    mailgun = {
      source  = "wgebis/mailgun"
      version = "~> 0.10"
    }
  }

  # The management bucket, beside the Cloudflare roots: nothing here lives in
  # Google, so the GitHub identity reads this prefix directly (state_access.tf
  # in org/gcp/_setup).
  backend "gcs" {
    prefix = "prd/mailgun"
  }
}

# The key comes from MAILGUN_API_KEY, which the workflow fills from a GitHub
# secret: the plan key on pull requests, the apply key on merge.
provider "mailgun" {}

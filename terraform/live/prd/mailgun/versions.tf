terraform {
  required_version = ">= 1.13"

  required_providers {
    mailgun = {
      source  = "wgebis/mailgun"
      version = "~> 0.10"
    }
    # Only the handoff object (handoff.tf).
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # The management bucket, beside the Cloudflare roots: nothing here lives in
  # Google, so the GitHub identity reads this prefix directly (state_access.tf
  # in org/gcp/_setup).
  backend "gcs" {
    prefix = "prd/mailgun"
  }
}

# The key comes from MAILGUN_API_KEY, which the workflow fills from the
# environment's secret (README, "Email").
provider "mailgun" {}

# The federated identity the workflow signs in with, which may write the one
# handoff object and nothing else in Google (state_access.tf in
# org/gcp/_setup).
provider "google" {}

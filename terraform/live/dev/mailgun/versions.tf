terraform {
  required_version = ">= 1.13"

  required_providers {
    mailgun = {
      source  = "wgebis/mailgun"
      version = "~> 0.10"
    }
    # The handoff object (handoff.tf) and the sending key's secret version
    # (sending_key.tf).
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9"
    }
  }

  # The management bucket, beside the Cloudflare roots: nothing here lives in
  # Google, so the GitHub identity reads this prefix directly (state_access.tf
  # in org/gcp/_setup).
  backend "gcs" {
    prefix = "dev/mailgun"
  }
}

# The key comes from MAILGUN_API_KEY, which the workflow fills from the
# environment's secret (docs/email.md).
provider "mailgun" {}

# The federated identity the workflow signs in with, which may write the one
# handoff object (state_access.tf in org/gcp/_setup) and versions of the one
# email key secret (the GCP root's secrets.tf), and nothing else in Google.
provider "google" {}

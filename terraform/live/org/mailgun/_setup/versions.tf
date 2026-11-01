terraform {
  required_version = ">= 1.13"

  required_providers {
    mailgun = {
      source  = "wgebis/mailgun"
      version = "~> 0.10"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    prefix = "org/mailgun/setup"
  }
}

# The admin key, from MAILGUN_API_KEY: _setup-apply.yml fills it from the
# `setup` environment's secret.
provider "mailgun" {}

# The bootstrap admin, which owns the environment projects; the secret
# versions above are the only thing this root does in Google.
provider "google" {}

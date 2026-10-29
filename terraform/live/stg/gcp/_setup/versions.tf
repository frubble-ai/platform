terraform {
  required_version = ">= 1.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    # Only for google_project_service_identity, which the stable provider does
    # not expose. Nothing else in this root uses it.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }

  # This root's own state lives in the management bucket, alongside every
  # other _setup root. Only the workload state goes in the environment's
  # bucket — so a credential that can read stg's workload state still cannot
  # read the identities that granted it that access.
  backend "gcs" {
    prefix = "stg/gcp/setup"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

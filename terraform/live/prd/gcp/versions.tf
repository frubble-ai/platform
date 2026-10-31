terraform {
  required_version = ">= 1.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    # The Cloud Run service module needs one beta field; see its versions.tf.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }

  # Workload state lives in the environment's own bucket, not the management
  # one. The identities that grant access to this environment are recorded in
  # the management bucket, which this root's credentials cannot read.
  backend "gcs" {
    prefix = "prd/gcp/live"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # The federated credential is the hub, which holds no permissions at all —
  # its single right is to become this spoke. Without this line Terraform runs
  # as the hub and fails on the first API call, in a way that reads like a
  # missing role rather than a missing hop.
  impersonate_service_account = var.spoke_service_account
}

# Same project, region and hop as above; only the Cloud Run service uses it.
provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  impersonate_service_account = var.spoke_service_account
}

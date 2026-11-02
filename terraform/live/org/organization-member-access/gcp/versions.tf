terraform {
  required_version = ">= 1.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Beside the _setup states, and applied by the same pipeline
  # (organization-member-access-cd.yml calls _setup-apply.yml).
  backend "gcs" {
    prefix = "org/organization-member-access/gcp"
  }
}

provider "google" {
  project = var.management_project_id
  region  = var.region
}

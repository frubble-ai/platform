terraform {
  required_version = ">= 1.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Applied by the setup pipeline's apply (organization-member-access-cd.yml
  # calls _setup-apply.yml) as the bootstrap admin, which owns the bucket.
  backend "gcs" {
    prefix = "org/organization-member-access/gcp"
  }
}

provider "google" {
  project = var.management_project_id
  region  = var.region
}

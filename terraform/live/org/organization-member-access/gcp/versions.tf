terraform {
  required_version = ">= 1.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9"
    }
  }

  backend "gcs" {
    prefix = "org/organization-member-access/gcp"
  }
}

provider "google" {
  project = var.management_project_id
  region  = var.region
}

terraform {
  # Pinned low enough that a contributor on an older CLI is told so, high
  # enough for the language features used here (terraform_data, optional
  # object attributes). CI pins one exact version; this is the floor.
  required_version = ">= 1.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.8"
    }
  }

}

provider "google" {
  project = var.management_project_id
  region  = var.region
}

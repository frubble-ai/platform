terraform {
  # Pinned low enough that a contributor on an older CLI is told so, high
  # enough for the language features used here (terraform_data, optional
  # object attributes). CI pins one exact version; this is the floor.
  required_version = ">= 1.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

}

provider "google" {
  project = var.management_project_id
  region  = var.region
}

# The budgets API has no project of its own and bills its calls to a quota
# project, which the provider only sends with user_project_override. Used by
# the budget alone, so no other resource changes how it authenticates.
provider "google" {
  alias   = "quota"
  project = var.management_project_id
  region  = var.region

  user_project_override = true
  billing_project       = var.management_project_id
}

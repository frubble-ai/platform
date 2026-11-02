terraform {
  required_version = ">= 1.13"

  required_providers {
    posthog = {
      source  = "posthog/posthog"
      version = "~> 1.0"
    }
  }

  backend "gcs" {
    prefix = "org/organization-member-access/posthog"
  }
}

provider "posthog" {
  organization_id = var.organization_id
}

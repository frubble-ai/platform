terraform {
  required_version = ">= 1.13"

  required_providers {
    posthog = {
      source  = "posthog/posthog"
      version = "~> 1.0"
    }
  }

  # Its own prefix, reachable only from the organization-member-access
  # environment (state_access.tf in org/gcp/_setup).
  backend "gcs" {
    prefix = "org/organization-member-access/posthog"
  }
}

# The API key comes from POSTHOG_API_KEY and the host defaults to PostHog
# Cloud US, so neither is written here.
provider "posthog" {
  organization_id = var.organization_id
}

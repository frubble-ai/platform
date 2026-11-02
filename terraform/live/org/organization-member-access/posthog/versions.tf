terraform {
  required_version = ">= 1.13"

  required_providers {
    posthog = {
      source  = "posthog/posthog"
      version = "~> 1.0"
    }
  }

  # Under org/posthog/live/, the prefix the PostHog apply identity may use
  # (state_access.tf in org/gcp/_setup), so no new grant is needed.
  backend "gcs" {
    prefix = "org/posthog/live/members"
  }
}

# The API key comes from POSTHOG_API_KEY and the host defaults to PostHog
# Cloud US, so neither is written here.
provider "posthog" {
  organization_id = var.organization_id
}

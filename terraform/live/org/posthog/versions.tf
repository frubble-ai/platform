terraform {
  required_version = ">= 1.13"

  required_providers {
    posthog = {
      source  = "posthog/posthog"
      version = "~> 1.0"
    }
  }

  # The management bucket, beside the Cloudflare roots. Nothing here lives in
  # Google, so the GitHub identity reads this prefix directly and no service
  # account stands in between (state_access.tf in org/gcp/_setup).
  backend "gcs" {
    prefix = "org/posthog/live"
  }
}

# The API key comes from POSTHOG_API_KEY and the host defaults to PostHog
# Cloud US, so neither is written here.
provider "posthog" {
  organization_id = var.organization_id
}

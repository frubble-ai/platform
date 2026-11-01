terraform {
  required_version = ">= 1.13"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # Cloudflare state lives in the management bucket, like the _setup roots.
  # It is not environment workload state: it describes the edge, which is
  # outside the environment project entirely.
  backend "gcs" {
    prefix = "prd/cloudflare"
  }
}

# No api_token here on purpose. The provider reads CLOUDFLARE_API_TOKEN from
# the environment, and the workflow puts a token there that it minted for this
# job and revokes when the job ends — including when the job fails. A token in
# tfvars would be long-lived and would end up in a file someone copies.
provider "cloudflare" {}

terraform {
  required_version = ">= 1.13"

  required_providers {
    # google-beta for one field, default_uri_disabled, which the GA provider
    # does not expose yet at this version. Same release train, same pin.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

terraform {
  required_version = ">= 1.13"

  required_providers {
    mailgun = {
      source  = "wgebis/mailgun"
      version = "~> 0.10"
    }
  }

  backend "gcs" {
    prefix = "org/mailgun/setup"
  }
}

# The bootstrap key, from MAILGUN_API_KEY in the environment of the person
# applying this root. Never in a file, never in GitHub.
provider "mailgun" {}

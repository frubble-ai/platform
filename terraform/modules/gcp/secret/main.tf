# Secret Manager ids accept only [a-zA-Z0-9_-], so the four-part path the
# standard asks for cannot use "/". The parts are kept and joined with "_",
# which stays unambiguous because the leaf names themselves contain hyphens:
#   frubble/stg/posthog/api-key -> frubble_stg_posthog_api-key
locals {
  secret_id = join("_", ["frubble", var.environment, var.domain, var.name])
}

resource "google_secret_manager_secret" "this" {
  project   = var.project_id
  secret_id = local.secret_id
  labels    = var.labels

  replication {
    user_managed {
      replicas {
        location = var.location
        customer_managed_encryption {
          kms_key_name = var.kms_key
        }
      }
    }
  }
}

# Terraform creates the container and a placeholder, and then stops being the
# owner of the value. A real value entered here would be written to state in
# clear text, which is why the standard separates "the secret exists" from
# "the secret has a value" and keeps only the first in code.
resource "google_secret_manager_secret_version" "placeholder" {
  secret      = google_secret_manager_secret.this.id
  secret_data = var.placeholder

  lifecycle {
    # Once a person adds the real version, this one is superseded. Without
    # this, every plan would show a diff trying to put the placeholder back.
    ignore_changes = [secret_data, enabled]
  }
}

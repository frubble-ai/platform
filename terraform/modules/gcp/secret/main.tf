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

# A value Terraform generates (README, "Secrets"): written through the
# write-only attribute, so it reaches Secret Manager and never the state.
# Only `value_wo_version` is recorded; bumping it writes a new value.
resource "google_secret_manager_secret_version" "managed" {
  count = var.generated ? 1 : 0

  secret                 = google_secret_manager_secret.this.id
  secret_data_wo         = var.value_wo
  secret_data_wo_version = var.value_wo_version

  # A version bump replaces this resource; the new version exists before the
  # old one goes, so a service starting in between still finds `latest`.
  lifecycle {
    create_before_destroy = true
  }
}

# A value that comes from outside (a third party's API key): Terraform creates
# the container and a placeholder, a person adds the real version, and from
# then on Terraform is not the owner of the value.
resource "google_secret_manager_secret_version" "placeholder" {
  count = var.generated ? 0 : 1

  secret      = google_secret_manager_secret.this.id
  secret_data = var.placeholder

  lifecycle {
    # Once a person adds the real version, this one is superseded. Without
    # this, every plan would show a diff trying to put the placeholder back.
    ignore_changes = [secret_data, enabled]
  }
}

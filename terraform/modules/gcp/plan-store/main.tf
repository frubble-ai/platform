# Where CI keeps the full output of every plan and apply. This repository is
# public, and so are its Actions logs, its artifacts (any signed-in GitHub
# user can download them) and its pull-request comments, so none of those
# carries raw Terraform output any more: they get a values-free summary, and
# the real thing lands here, readable by the organization only.
#
# A bucket of its own rather than a prefix in the state bucket:
#   - Readers of plans never get a binding on the state bucket. Listing is a
#     bucket-level permission that no prefix condition can narrow, so sharing
#     the bucket would show developers the name of every state object.
#   - Its own key. Revoking or rotating access to plans never touches state.
#   - Its own lifecycle. Plans are evidence for a review, not a record, so
#     they expire; state must never expire.

resource "google_kms_key_ring" "plans" {
  name     = "${var.name}-plans"
  project  = var.project_id
  location = var.location
}

resource "google_kms_crypto_key" "plans" {
  name     = "plans"
  key_ring = google_kms_key_ring.plans.id
  purpose  = "ENCRYPT_DECRYPT"

  rotation_period = "${var.key_rotation_days * 24 * 60 * 60}s"
}

# GCS encrypts and decrypts with the bucket's default key as its own service
# agent, never as the caller, so only the agent needs the key. Callers need
# object permissions only.
data "google_storage_project_service_account" "gcs" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_agent" {
  crypto_key_id = google_kms_crypto_key.plans.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_storage_bucket" "plans" {
  name     = var.name
  project  = var.project_id
  location = var.location
  labels   = var.labels

  # IAM only, and never public: see the state-bucket module.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  encryption {
    default_kms_key_name = google_kms_crypto_key.plans.id
  }

  # Writers hold objectCreator, which cannot overwrite or delete, so every
  # object is written once and nothing needs versions to recover it.
  versioning {
    enabled = false
  }

  # A deleted plan should be gone, not kept for another week by soft delete:
  # a plan can hold values from inside resources.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_agent]
}

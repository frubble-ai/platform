# A Terraform state file is the most sensitive artifact in the repository: it
# records every resource, and for some resource types it records the values
# inside them. This module is the single place that decides how that file is
# stored, so no root can accidentally create a weaker bucket.

# Each bucket carries its own key. A key is the smallest unit that can be
# revoked, so sharing one key across environments would mean revoking stg's key
# also locks prd out of its state.
resource "google_kms_key_ring" "state" {
  name     = "${var.name}-state"
  project  = var.project_id
  location = var.location
}

resource "google_kms_crypto_key" "state" {
  name     = "state"
  key_ring = google_kms_key_ring.state.id
  purpose  = "ENCRYPT_DECRYPT"

  rotation_period = "${var.key_rotation_days * 24 * 60 * 60}s"

  # Rotation alone does not re-encrypt what is already written: old state
  # versions stay readable only while the key version that wrote them exists.
  # The delay is therefore a recovery window, not a cleanup setting.
  destroy_scheduled_duration = "${var.key_destroy_delay_days * 24 * 60 * 60}s"

  # Losing this key loses every state file it ever encrypted, which is
  # unrecoverable by any means. Terraform must refuse to delete it.
  lifecycle {
    prevent_destroy = true
  }
}

# GCS encrypts with the key as itself, not as the caller, so its own service
# agent needs access. Without this the bucket fails to create with a confusing
# "permission denied on the key" that looks like a caller problem.
data "google_storage_project_service_account" "gcs" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_agent" {
  crypto_key_id = google_kms_crypto_key.state.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_storage_bucket" "state" {
  name     = var.name
  project  = var.project_id
  location = var.location
  labels   = var.labels

  # Terraform's GCS backend locks natively, by writing a lock object and
  # relying on GCS generation preconditions. There is no second service to
  # configure and no lock table to drift — but it does mean the bucket itself
  # must stay writable by anything that plans, which is why the plan identity
  # gets object write access and nothing more.

  # Recover from a bad apply by restoring a previous generation. Without this,
  # one corrupt write is the end of the record of what exists.
  versioning {
    enabled = true
  }

  # Access is granted by IAM only. ACLs are per-object and invisible in any
  # policy review, so a single mislabeled object could be world-readable
  # without anything in IAM showing it.
  uniform_bucket_level_access = true

  # Belt to the above brace: even an IAM binding that names allUsers is
  # refused while this is enforced.
  public_access_prevention = "enforced"

  # Writes that do not name a key still land encrypted under this one. The
  # org policy constraints/gcp.restrictNonCmekServices is what rejects a write
  # that tries to opt out; this is what makes the default correct.
  encryption {
    default_kms_key_name = google_kms_crypto_key.state.id
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.noncurrent_version_retention_days
      with_state                 = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = var.abort_incomplete_upload_days
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  # Deleting a state bucket orphans the infrastructure it tracked: the
  # resources keep running and billing with nothing left that knows about them.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_agent]
}

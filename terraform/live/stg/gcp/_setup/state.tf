# The environment's own state bucket, with its own key. Workload state lives
# here; this root's state does not.
module "state" {
  source = "../../../../modules/gcp/state-bucket"

  name       = "${var.project_id}-tfstate"
  project_id = var.project_id
  location   = var.region

  labels = {
    env          = var.environment
    component    = "state"
    "managed-by" = "terraform"
  }
}

# Secrets get a key separate from state. Revoking one must not take the other
# down with it: losing access to state is an outage, losing access to secrets
# is a different outage, and conflating them means every recovery is both.
resource "google_kms_key_ring" "secrets" {
  name     = "${var.project_id}-secrets"
  project  = var.project_id
  location = var.region
}

resource "google_kms_crypto_key" "secrets" {
  name            = "secrets"
  key_ring        = google_kms_key_ring.secrets.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "2592000s" # 30 days

  destroy_scheduled_duration = "2592000s"

  lifecycle {
    prevent_destroy = true
  }
}

# Secret Manager encrypts as its own service agent, not as the caller — and
# that agent does not exist until something asks for it. Enabling the API is
# not enough: the first CMEK secret would fail with "service account does not
# exist", which reads like a typo rather than a missing bootstrap step.
resource "google_project_service_identity" "secretmanager" {
  provider = google-beta

  project = var.project_id
  service = "secretmanager.googleapis.com"
}


resource "google_kms_crypto_key_iam_member" "secretmanager_agent" {
  crypto_key_id = google_kms_crypto_key.secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.secretmanager.email}"
}

# The workload root reads this root's outputs through remote state, and that
# state lives in the management bucket. Read-only, and narrowed by an IAM
# condition to this environment's own prefix — uniform bucket-level access
# allows conditions on bucket bindings, so the narrowing is in the grant
# itself rather than in a deny policy somewhere else.
locals {
  env_spokes = [module.plan_spoke.email, module.apply_spoke.email]
}

resource "google_storage_bucket_iam_member" "spokes_read_management" {
  for_each = toset(local.env_spokes)

  bucket = var.management_state_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${each.value}"

  # Only this environment's own _setup outputs. Bucket-wide, as it was, the
  # plan spoke — which pull-request code can reach — could read the org and
  # the other environment's _setup states. The comment here used to claim a
  # deny policy made that safe; no such policy existed.
  condition {
    title       = "only this environment's setup state"
    description = "Objects under ${var.environment}/gcp/setup and nothing else."
    expression  = "resource.name.startsWith('projects/_/buckets/${var.management_state_bucket}/objects/${var.environment}/gcp/setup')"
  }
}

# Same reason as the Cloudflare identities: the backend lists the bucket on
# init, listing is a bucket-level operation, and a prefix condition cannot
# express it. Names only — the conditioned grant above is what controls which
# objects can actually be read.
resource "google_storage_bucket_iam_member" "spokes_list_management" {
  for_each = toset(local.env_spokes)

  bucket = var.management_state_bucket
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${each.value}"
}

resource "google_kms_crypto_key_iam_member" "spokes_decrypt_management" {
  for_each = toset(local.env_spokes)

  crypto_key_id = local.org.management_state_key
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = "serviceAccount:${each.value}"
}

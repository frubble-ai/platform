output "name" {
  description = "Bucket name, passed to `terraform init -backend-config=bucket=...` by the workflows."
  value       = google_storage_bucket.state.name
}

output "kms_key_id" {
  description = "Key protecting the bucket. Any identity that reads or writes state also needs encrypterDecrypter on this."
  value       = google_kms_crypto_key.state.id
}

output "kms_key_ring_id" {
  description = "Key ring holding the state key."
  value       = google_kms_key_ring.state.id
}

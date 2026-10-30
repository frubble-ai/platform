output "name" {
  description = "Bucket name. CI reads it from the PLAN_STORE_BUCKET repository variable."
  value       = google_storage_bucket.plans.name
}

output "kms_key_id" {
  description = "Default key of the bucket. Only the GCS service agent holds it."
  value       = google_kms_crypto_key.plans.id
}

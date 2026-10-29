output "id" {
  description = "Full resource id, for IAM bindings that name this one secret."
  value       = google_secret_manager_secret.this.id
}

output "secret_id" {
  description = "Short id as it appears in the console."
  value       = google_secret_manager_secret.this.secret_id
}

output "email" {
  description = "Spoke service account email."
  value       = google_service_account.spoke.email
}

output "member" {
  description = "IAM member string for use in deny policies and resource-level bindings."
  value       = "serviceAccount:${google_service_account.spoke.email}"
}

output "principal" {
  description = <<-EOT
    Principal identifier in the form IAM deny policies expect. Deny policies
    name a service account by its email, not by its numeric unique id — the
    id is rejected with INVALID_PRINCIPAL, which reads like the account does
    not exist rather than like the wrong field was used.
  EOT
  value       = "principal://iam.googleapis.com/projects/-/serviceAccounts/${google_service_account.spoke.email}"
}

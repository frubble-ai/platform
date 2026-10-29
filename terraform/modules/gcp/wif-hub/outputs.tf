output "email" {
  description = "Hub service account email. CI names this as the account to impersonate after federating."
  value       = google_service_account.hub.email
}

output "member" {
  description = "IAM member string, for the spoke that will trust this hub."
  value       = "serviceAccount:${google_service_account.hub.email}"
}

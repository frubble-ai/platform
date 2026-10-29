output "credential_email" {
  description = "Identity the run is actually using. Worth echoing in logs: it is the single fact that explains most permission failures."
  value       = data.google_client_openid_userinfo.current.email
}

output "self_link" {
  description = "What a backend service attaches."
  value       = google_compute_security_policy.this.self_link
}

output "name" {
  value = google_compute_security_policy.this.name
}

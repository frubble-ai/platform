output "deny_policy_id" {
  description = "Deny policy guarding secret values, for the QA step that confirms a developer is refused."
  value       = google_iam_deny_policy.no_secret_values.id
}

output "project_id" {
  value = posthog_project.frubble.id
}

# The project token that SDKs send events with. Not a secret to PostHog — it
# ships in client code — but it is kept out of plan output all the same.
output "project_api_token" {
  value     = posthog_project.frubble.api_token
  sensitive = true
}

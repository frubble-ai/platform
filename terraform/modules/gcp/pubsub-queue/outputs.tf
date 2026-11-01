output "topic" {
  description = "Topic name, as the API publishes to it."
  value       = google_pubsub_topic.this.name
}

output "push_subscription" {
  value = google_pubsub_subscription.push.name
}

output "dead_letter_subscription" {
  description = "Where refused messages wait; the alert watches its backlog."
  value       = google_pubsub_subscription.dead_letter.name
}

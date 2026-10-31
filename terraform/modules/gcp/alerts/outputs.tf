output "notification_channel_id" {
  description = "The email channel, for policies defined elsewhere."
  value       = google_monitoring_notification_channel.email.id
}

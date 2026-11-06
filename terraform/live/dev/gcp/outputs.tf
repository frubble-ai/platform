output "registry_url" {
  value = module.registry.url
}

output "load_balancer_ip" {
  description = "Address api_hostname must resolve to. The Cloudflare root reads it from the handoff object (handoff.tf)."
  value       = module.load_balancer.ip_address
}

output "certificate_dns_authorization" {
  description = "CNAME that proves control of api_hostname to Certificate Manager. Published before the hostname itself, and kept: renewals reuse it."
  value       = module.load_balancer.dns_authorization_records["api"]
}

output "api_service_name" {
  value = module.api_service.name
}

output "migrate_job_name" {
  description = "Job the deploy executes before a rollout."
  value       = module.migrate_job.name
}

output "database_instance" {
  description = "Cloud SQL instance, for the hand step that sets the application user's password."
  value       = module.database.instance_name
}

output "worker_service_name" {
  value = module.worker_service.name
}

output "emails_topic" {
  value = module.emails_queue.topic
}

output "emails_dead_letter_subscription" {
  description = "Where emails the worker gave up on wait."
  value       = module.emails_queue.dead_letter_subscription
}

output "app_service_name" {
  value = module.app_service.name
}

output "osiris_service_name" {
  value = module.osiris_service.name
}

output "osiris_worker_service_name" {
  value = module.osiris_worker_service.name
}

output "osiris_worker_uri" {
  description = "Worker URL Cloud Tasks calls. OSIRIS_WORKER_URL is this shape; compare after the first apply."
  value       = module.osiris_worker_service.uri
}

output "osiris_migrate_job_name" {
  value = module.osiris_migrate_job.name
}

output "osiris_events_topic" {
  value = google_pubsub_topic.osiris_events.name
}

output "osiris_tasks_queue" {
  value = google_cloud_tasks_queue.osiris.name
}

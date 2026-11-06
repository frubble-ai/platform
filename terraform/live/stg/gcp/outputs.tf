# Null while stg is switched off (var.enabled): the modules behind them are
# disabled, and a disabled module is null.
output "registry_url" {
  value = try(module.registry.url, null)
}

output "load_balancer_ip" {
  description = "Address api_hostname must resolve to. The Cloudflare root reads it from the handoff object (handoff.tf)."
  value       = try(module.load_balancer.ip_address, null)
}

output "certificate_dns_authorization" {
  description = "CNAME that proves control of api_hostname to Certificate Manager. Published before the hostname itself, and kept: renewals reuse it."
  value       = try(module.load_balancer.dns_authorization_records["api"], null)
}

output "api_service_name" {
  value = try(module.api_service.name, null)
}

output "migrate_job_name" {
  description = "Job the deploy executes before a rollout."
  value       = try(module.migrate_job.name, null)
}

output "database_instance" {
  description = "Cloud SQL instance, for the hand step that sets the application user's password."
  value       = try(module.database.instance_name, null)
}

output "worker_service_name" {
  value = try(module.worker_service.name, null)
}

output "emails_topic" {
  value = try(module.emails_queue.topic, null)
}

output "emails_dead_letter_subscription" {
  description = "Where emails the worker gave up on wait."
  value       = try(module.emails_queue.dead_letter_subscription, null)
}

output "app_service_name" {
  value = try(module.app_service.name, null)
}

output "osiris_service_name" {
  value = try(module.osiris_service.name, null)
}

output "osiris_worker_service_name" {
  value = try(module.osiris_worker_service.name, null)
}

output "osiris_worker_uri" {
  description = "Worker URL Cloud Tasks calls. OSIRIS_WORKER_URL is this shape; compare after the first apply."
  value       = try(module.osiris_worker_service.uri, null)
}

output "osiris_migrate_job_name" {
  value = try(module.osiris_migrate_job.name, null)
}

output "osiris_events_topic" {
  value = try(google_pubsub_topic.osiris_events.name, null)
}

output "osiris_tasks_queue" {
  value = try(google_cloud_tasks_queue.osiris.name, null)
}

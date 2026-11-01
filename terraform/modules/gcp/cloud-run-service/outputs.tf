output "name" {
  description = "Service name, as the load balancer's NEG and the deploy refer to it."
  value       = google_cloud_run_v2_service.this.name
}

output "id" {
  description = "Full resource id, for IAM bindings on the service."
  value       = google_cloud_run_v2_service.this.id
}

output "max_instances" {
  description = "The scaling ceiling, for the saturation alert."
  value       = var.max_instances
}

output "uri" {
  description = "The run.app URL, for same-project callers such as a Pub/Sub push subscription. Empty when `default_uri_disabled`."
  value       = google_cloud_run_v2_service.this.uri
}

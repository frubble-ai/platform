output "name" {
  description = "Service name, as the load balancer's NEG and the deploy refer to it."
  value       = google_cloud_run_v2_service.this.name
}

output "id" {
  description = "Full resource id, for IAM bindings on the service."
  value       = google_cloud_run_v2_service.this.id
}

output "uri" {
  description = "The run.app URL. Unreachable directly with the default ingress; kept for diagnostics."
  value       = google_cloud_run_v2_service.this.uri
}

output "max_instances" {
  description = "The scaling ceiling, for the saturation alert."
  value       = var.max_instances
}

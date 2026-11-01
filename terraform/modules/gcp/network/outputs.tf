output "network_id" {
  description = "Full network id, for Cloud SQL's private IP and the workloads' VPC access."
  value       = google_compute_network.this.id
}

output "subnetwork_id" {
  description = "Subnet the workloads send through."
  value       = google_compute_subnetwork.workloads.id
}

output "private_services_connection" {
  description = "The peering. A Cloud SQL instance with a private address depends on it."
  value       = google_service_networking_connection.private_services.id
}

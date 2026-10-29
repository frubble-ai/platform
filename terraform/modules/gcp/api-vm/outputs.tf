output "instance_name" {
  description = "VM name. Used by the deploy workflow and by the developer IAP condition."
  value       = google_compute_instance.api.name
}

output "instance_zone" {
  description = "Zone the VM runs in."
  value       = google_compute_instance.api.zone
}

output "service_account_email" {
  description = "Identity the box runs as."
  value       = var.service_account_email
}

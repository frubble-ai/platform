output "name" {
  description = "Job name, as the deploy refers to it."
  value       = google_cloud_run_v2_job.this.name
}

output "id" {
  value = google_cloud_run_v2_job.this.id
}

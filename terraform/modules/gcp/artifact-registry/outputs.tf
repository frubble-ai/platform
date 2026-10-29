output "name" {
  description = "Repository id."
  value       = google_artifact_registry_repository.this.name
}

output "location" {
  description = "Repository region, needed to build the image URL."
  value       = google_artifact_registry_repository.this.location
}

output "url" {
  description = "Registry host and path images are pushed to."
  value       = "${google_artifact_registry_repository.this.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}

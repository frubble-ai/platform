output "project_id" {
  description = "Project id, for providers and for the pin check in each root."
  value       = google_project.this.project_id
}

output "number" {
  description = "Project number. Service agent members are addressed by number, not id."
  value       = google_project.this.number
}

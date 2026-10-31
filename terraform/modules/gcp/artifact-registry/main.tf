resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.name
  format        = "DOCKER"
  description   = var.description
  labels        = var.labels

  # A tag names one image forever: a deploy of commit X is the same bytes on
  # every run, and a re-run reuses the push instead of repeating it.
  docker_config {
    immutable_tags = var.immutable_tags
  }

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_recent_versions
    }
  }
}

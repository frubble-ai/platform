resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.name
  format        = "DOCKER"
  description   = var.description
  labels        = var.labels

  # Tags stay mutable: with immutable tags Artifact Registry cannot delete a
  # tagged image, so the retention below would bound nothing. The deploy
  # never pushes over a tag that exists; once cleanup has deleted that
  # version, a re-run of the same old commit builds and pushes it again.

  # DELETE is what removes an image; KEEP is the exception to it. Without the
  # DELETE rule the KEEP rule bounds nothing and every deploy adds an image
  # that stays.
  cleanup_policies {
    id     = "delete-all"
    action = "DELETE"
    condition {
      tag_state = "ANY"
    }
  }

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_recent_versions
    }
  }
}

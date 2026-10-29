# See the equivalent file in org/gcp/_setup: the bucket's default key makes
# unencrypted writes unlikely, and this constraint makes them impossible.
resource "google_org_policy_policy" "requires_cmek" {
  name   = "projects/${var.project_id}/policies/gcp.restrictNonCmekServices"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      values {
        denied_values = ["storage.googleapis.com"]
      }
    }
  }

  depends_on = [google_project_service.orgpolicy]
}

resource "google_project_service" "orgpolicy" {
  project = var.project_id
  service = "orgpolicy.googleapis.com"

  disable_on_destroy = false
}

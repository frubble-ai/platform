# The state buckets name a customer-managed key, so writes that say nothing
# land encrypted under it. That is a default, not a rule: a caller can still
# ask for Google-managed encryption explicitly, and nothing refuses.
#
# This is what refuses. The constraint rejects creating a Cloud Storage
# resource that does not use a customer-managed key, which turns "unencrypted
# writes are unlikely" into "unencrypted writes are impossible".
#
# Scoped per project rather than set at the organization, because the
# organization still contains the pre-rebuild project, and a bucket there was
# created without CMEK.
resource "google_org_policy_policy" "management_requires_cmek" {
  name   = "projects/${var.management_project_id}/policies/gcp.restrictNonCmekServices"
  parent = "projects/${var.management_project_id}"

  spec {
    rules {
      values {
        denied_values = ["storage.googleapis.com"]
      }
    }
  }

  depends_on = [google_project_service.management_orgpolicy]
}

resource "google_project_service" "management_orgpolicy" {
  project = var.management_project_id
  service = "orgpolicy.googleapis.com"

  disable_on_destroy = false
}

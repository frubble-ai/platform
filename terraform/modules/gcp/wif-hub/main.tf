# A hub is deliberately powerless. It holds no project roles at all: its only
# capability is granted elsewhere, by the spoke that chooses to trust it. That
# inversion is the point — the list of what CI may do lives in the environment
# being changed, not in the identity doing the changing.
resource "google_service_account" "hub" {
  account_id   = var.name
  project      = var.project_id
  display_name = var.description
  description  = var.description
}

# GitHub presents an OIDC token; this is the rule that decides whether the
# exchange is allowed. Binding on a composite attribute means every claim in
# the entry must match at once. Binding on `attribute.repository` alone would
# let any workflow in the repository — including one added by an outside
# contributor's pull request — request this identity.
resource "google_service_account_iam_member" "federated" {
  for_each = toset(var.allowed_values)

  service_account_id = google_service_account.hub.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.pool_name}/attribute.${var.attribute}/${each.value}"
}

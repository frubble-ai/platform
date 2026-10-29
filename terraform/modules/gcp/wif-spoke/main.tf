resource "google_service_account" "spoke" {
  account_id   = var.name
  project      = var.project_id
  display_name = var.description
  description  = var.description
}

# Authoritative on purpose. `_member` would add the hub and leave any other
# token creator in place; `_binding` makes the hub the complete list, so a
# second path to this identity cannot be added without showing up as a diff
# in this repository.
resource "google_service_account_iam_binding" "trusts_hub_only" {
  service_account_id = google_service_account.spoke.name
  role               = "roles/iam.serviceAccountTokenCreator"
  members            = [var.hub_member]
}

resource "google_project_iam_member" "roles" {
  for_each = { for r in var.roles : r.role => r }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.spoke.email}"

  dynamic "condition" {
    for_each = each.value.expression == null ? [] : [each.value]
    content {
      title      = condition.value.title
      expression = condition.value.expression
    }
  }
}

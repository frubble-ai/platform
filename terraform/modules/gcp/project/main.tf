resource "google_project" "this" {
  project_id      = var.project_id
  name            = var.name
  org_id          = var.org_id
  billing_account = var.billing_account
  labels          = var.labels

  # The default VPC ships with permissive firewall rules, including SSH from
  # anywhere. Creating it and deleting it later leaves a window; not creating
  # it leaves none.
  auto_create_network = false

  # A project is the blast-radius boundary. Deleting one takes every resource
  # inside it, so removing it has to be a deliberate, manual act.
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_service" "enabled" {
  for_each = toset(var.apis)

  project = google_project.this.project_id
  service = each.value

  # Leave the API on when the resource is removed from config. Disabling an
  # API disables every resource using it across the project, which is a far
  # larger action than deleting the Terraform resource that asked for it.
  disable_on_destroy         = false
  disable_dependent_services = false
}

module "pin" {
  source = "../../../../modules/gcp/project-pin"

  expected_project_id         = var.project_id
  allow_user_credentials      = true
  additional_allowed_projects = [var.management_project_id]
}

# False, unlike the _setup roots: this root is applied by CI only. A run from
# a laptop fails here rather than succeeding with a person's broader rights
# and leaving a state file CI cannot reproduce.
module "pin" {
  source = "../../../modules/gcp/project-pin"

  expected_project_id    = var.project_id
  allow_user_credentials = false
}

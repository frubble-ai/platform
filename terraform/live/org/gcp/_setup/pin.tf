# _setup roots are applied by a person with the bootstrap admin identity, so a
# human credential is accepted here. Every CI root leaves this false, which is
# what makes a laptop-run of a CI root fail instead of quietly succeeding.
module "pin" {
  source = "../../../../modules/gcp/project-pin"

  expected_project_id    = var.management_project_id
  allow_user_credentials = true
}

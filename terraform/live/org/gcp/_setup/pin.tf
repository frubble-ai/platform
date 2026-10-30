# _setup roots are applied by a person once, and by setup-cd after that; both
# run as the bootstrap admin, and the hand path is what a human credential is
# accepted for here. Every CI root leaves this false, which is what makes a
# laptop-run of a CI root fail instead of quietly succeeding.
module "pin" {
  source = "../../../../modules/gcp/project-pin"

  expected_project_id    = var.management_project_id
  allow_user_credentials = true
}

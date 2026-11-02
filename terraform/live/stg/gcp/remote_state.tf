data "terraform_remote_state" "setup" {
  backend = "gcs"

  config = {
    bucket = var.management_state_bucket
    prefix = "${module.shared.environment}/gcp/setup"

    # The backend authenticates on its own, outside the provider, so it does
    # not inherit the provider's impersonation and has to be told separately.
    impersonate_service_account = var.spoke_service_account
  }
}

data "terraform_remote_state" "setup" {
  backend = "gcs"

  config = {
    bucket = var.management_state_bucket
    prefix = "${var.environment}/gcp/setup"

    # The backend authenticates on its own, outside the provider, so it does
    # not inherit the provider's impersonation and has to be told separately.
    impersonate_service_account = var.spoke_service_account
  }
}

locals {
  setup = data.terraform_remote_state.setup.outputs
  name  = "frubble-${var.environment}"

  # Base labels. `component` is added at each module call, because the point
  # of the label is to tell the parts apart in billing and in an audit — one
  # value shared by every resource would not.
  labels = {
    env          = var.environment
    "managed-by" = "terraform"
  }
}

# Values cross root boundaries only this way. Copying a hub email into a
# tfvars file by hand would work until the hub is recreated, and then fail as
# a permission error with nothing pointing at the stale copy.
data "terraform_remote_state" "org" {
  backend = "gcs"

  config = {
    bucket = var.management_state_bucket
    prefix = "org/gcp/setup"
  }
}

locals {
  org = data.terraform_remote_state.org.outputs

  plan_hub  = "serviceAccount:${local.org.plan_hubs[var.environment]}"
  apply_hub = "serviceAccount:${local.org.apply_hubs[var.environment]}"
}

locals {
  # Only stg has one: the application deploys to stg and nowhere else.
  backend_deploy_hub = "serviceAccount:${local.org.backend_deploy_hub}"
  tunnel_token_hub   = "serviceAccount:${local.org.tunnel_token_hubs[var.environment]}"
}

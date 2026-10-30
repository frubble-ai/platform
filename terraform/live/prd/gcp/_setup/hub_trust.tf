# The hubs this environment's deploys sign in through live in the management
# project, and the rule deciding who may sign in — the workload identity
# binding on each — is owned by the workload root, so a renamed workflow or
# GitHub environment is a planned, reviewed, CI-applied change. These grants
# are what make that possible and nothing more: the apply spoke may read and
# set the policy of exactly these accounts, the plan spoke may read it.
locals {
  env_hubs = merge(
    { tunnel-token = local.org.tunnel_token_hub_names[var.environment] },
    var.environment == "stg" ? { backend-deploy = local.org.backend_deploy_hub_name } : {},
  )
}

resource "google_service_account_iam_member" "apply_edits_hub_trust" {
  for_each = local.env_hubs

  service_account_id = each.value
  role               = local.org.hub_trust_editor_role
  member             = module.apply_spoke.member
}

# Plan runs on pull-request code; reading a trust rule reveals a workflow
# path and a branch, both of which are in this repository already.
resource "google_service_account_iam_member" "plan_reads_hub_trust" {
  for_each = local.env_hubs

  service_account_id = each.value
  role               = "roles/iam.serviceAccountViewer"
  member             = module.plan_spoke.member
}

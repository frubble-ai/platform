# The hub this environment's deploy signs in through lives in the management
# project, and the rule deciding who may sign in — the workload identity
# binding on it — is owned by the workload root, so a renamed workflow or
# GitHub environment is a planned, reviewed, CI-applied change. These grants
# are what make that possible: the apply spoke may read and set the whole IAM
# policy of exactly this account, the plan spoke may read it. Whole, because
# setIamPolicy cannot be narrowed to one binding; what bounds it is that the
# hub holds nothing and can only become this environment's deploy spoke,
# which the apply spoke already outranks.
#
# Authoritative per role, like the trust binding in the workload root: a
# member that appears under either role from anywhere else is a diff here.
locals {
  env_hubs = var.environment == "stg" ? { backend-deploy = local.org.backend_deploy_hub_name } : {}
}

resource "google_service_account_iam_binding" "apply_edits_hub_trust" {
  for_each = local.env_hubs

  service_account_id = each.value
  role               = local.org.hub_trust_editor_role
  members            = [module.apply_spoke.member]
}

# Plan runs on pull-request code; reading a trust rule reveals a workflow
# path and a branch, both of which are in this repository already.
resource "google_service_account_iam_binding" "plan_reads_hub_trust" {
  for_each = local.env_hubs

  service_account_id = each.value
  role               = "roles/iam.serviceAccountViewer"
  members            = [module.plan_spoke.member]
}

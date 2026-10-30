# Who may become this environment's deploy identities.
#
# The hub accounts live in the management project (org/gcp/_setup). The rule
# naming who may sign in to each — a workload identity binding on the
# account — is here, because it changes with this environment's workflows,
# and this root is the one CI plans on every pull request and applies on
# merge. An entry is the complete set of claims that must match at once:
# repository | workflow file | GitHub environment | ref, as org/gcp/_setup's
# apply provider maps them. There are no wildcards.
locals {
  pool  = local.setup.workload_identity_pool
  repos = local.setup.repositories

  # The tunnel-token step runs directly in <env>-cd.yml, so that file is the
  # job_workflow_ref. prd names a workflow that does not exist yet; the entry
  # is inert until someone adds it.
  tunnel_token_entries = [
    "${local.repos.platform}|${local.repos.platform}/.github/workflows/${var.environment}-cd.yml|${var.environment}|refs/heads/dev",
  ]

  # The application deploys from its own branch, in an environment named
  # after the component, since that name is what GitHub lists the deployment
  # under. Only stg: the application deploys nowhere else.
  backend_deploy_entries = var.environment == "stg" ? [
    "${local.repos.backend}|${local.repos.backend}/.github/workflows/backend-cd.yml|backend-stg|refs/heads/stg",
  ] : []
}

# Authoritative: this root is the only owner of each hub's members since
# org/gcp/_setup forgot them without destroying, so the first apply sets the
# same list and changes nothing, and a member added anywhere else — by hand,
# or by the apply spoke's own policy right — is a diff in the next plan.
resource "google_service_account_iam_binding" "tunnel_token_trust" {
  service_account_id = local.setup.tunnel_token_hub_name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    for entry in local.tunnel_token_entries :
    "principalSet://iam.googleapis.com/${local.pool}/attribute.apply_entry/${entry}"
  ]
}

resource "google_service_account_iam_binding" "backend_deploy_trust" {
  count = length(local.backend_deploy_entries) > 0 ? 1 : 0

  service_account_id = local.setup.backend_deploy_hub_name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    for entry in local.backend_deploy_entries :
    "principalSet://iam.googleapis.com/${local.pool}/attribute.apply_entry/${entry}"
  ]
}

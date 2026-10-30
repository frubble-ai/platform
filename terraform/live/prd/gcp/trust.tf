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

resource "google_service_account_iam_member" "tunnel_token_trust" {
  for_each = toset(local.tunnel_token_entries)

  service_account_id = local.setup.tunnel_token_hub_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool}/attribute.apply_entry/${each.value}"
}

resource "google_service_account_iam_member" "backend_deploy_trust" {
  for_each = toset(local.backend_deploy_entries)

  service_account_id = local.setup.backend_deploy_hub_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool}/attribute.apply_entry/${each.value}"
}

# These bindings existed before this root owned them: org/gcp/_setup forgot
# them without destroying, so nothing was ever untrusted in between. Once
# imported, the blocks are no-ops and can go in a later tidy-up.
import {
  for_each = toset(local.tunnel_token_entries)

  to = google_service_account_iam_member.tunnel_token_trust[each.key]
  id = "${local.setup.tunnel_token_hub_name} roles/iam.workloadIdentityUser principalSet://iam.googleapis.com/${local.pool}/attribute.apply_entry/${each.value}"
}

import {
  for_each = toset(local.backend_deploy_entries)

  to = google_service_account_iam_member.backend_deploy_trust[each.key]
  id = "${local.setup.backend_deploy_hub_name} roles/iam.workloadIdentityUser principalSet://iam.googleapis.com/${local.pool}/attribute.apply_entry/${each.value}"
}

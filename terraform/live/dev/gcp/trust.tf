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

  # The application deploys from its own branch, in an environment named
  # after the component, since that name is what GitHub lists the deployment
  # under: the backend's workflow and the web app's, each with its own, and
  # the database reset, which runs the migration job in the backend's
  # environment. dev deploys from the application's `dev` branch into
  # `backend-dev` and `app-dev`, through its own hub: no entry here names a
  # stg environment or branch, and stg's rules name nothing of dev's.
  backend_deploy_entries = [
    "${local.repos.backend}|${local.repos.backend}/.github/workflows/backend-cd.yml|backend-dev|refs/heads/dev",
    "${local.repos.backend}|${local.repos.backend}/.github/workflows/db-reset.yml|backend-dev|refs/heads/dev",
    "${local.repos.backend}|${local.repos.backend}/.github/workflows/app-cd.yml|app-dev|refs/heads/dev",
  ]
}

# Authoritative: this root is the only owner of the hub's members since
# org/gcp/_setup forgot them without destroying, so the first apply sets the
# same list and changes nothing, and a member added under this role from
# anywhere else — by hand, or by the apply spoke's own policy right — is a
# diff in the next plan. The _setup root binds the two other roles the hub
# carries the same way. A member under any further role, tokenCreator or
# keyAdmin say, is the remaining blind spot: nothing in this repository
# declares such a role on a hub, so nothing would report one.
resource "google_service_account_iam_binding" "backend_deploy_trust" {
  count = length(local.backend_deploy_entries) > 0 ? 1 : 0

  service_account_id = local.setup.backend_deploy_hub_name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    for entry in local.backend_deploy_entries :
    "principalSet://iam.googleapis.com/${local.pool}/attribute.apply_entry/${entry}"
  ]
}

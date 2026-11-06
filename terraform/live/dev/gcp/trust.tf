# Who may become this environment's deploy identities.
#
# The hub accounts live in the management project (org/gcp/_setup). The rule
# naming who may sign in to each — a workload identity binding on the
# account — is here, because it changes with this environment's workflows,
# and this root is the one CI plans on every pull request and applies on
# merge. An entry is the complete set of claims that must match at once:
# repository | workflow file | GitHub environment | ref, as org/gcp/_setup's
# apply provider maps them (apply_entry), or the same with any branch as
# `branch` and the run's actor id added (deploy_entry). There are no wildcards.
locals {
  pool  = local.setup.workload_identity_pool
  repos = local.setup.repositories

  # The application deploys in an environment named after the component,
  # since that name is what GitHub lists the deployment under: the backend's
  # workflow and the web app's, each with its own. dev deploys whatever branch
  # the run is on, so it can try a branch before it merges: these name the
  # apply provider's deploy_entry, whose ref part is `branch` for any branch
  # (never a tag or a pull request). The repository, the workflow file and the
  # dev environment must still all match. No entry here names a stg
  # environment, and stg's rules name nothing of dev's.
  #
  # deploy_entry ends with the GitHub id of the run's actor (who pushed, or who
  # ran it by hand), and only frubble-ai's members are listed here, so nobody
  # else (an outside collaborator, a bot) can deploy to dev, whichever branch
  # and whatever the workflow file says. This is the list of the organization's
  # members, by id, which never changes with a rename: add a member here when
  # they join, and take them out when they leave
  # (`gh api orgs/frubble-ai/members --jq '.[] | "\(.login) \(.id)"'`).
  #
  # A re-run keeps its first run's actor id, and the token cannot say who
  # started the re-run, so this list alone would let anyone able to re-run a
  # member's deploy (a GitHub App with Actions: write, such as Slack's or
  # Linear's) redeploy it. frubble-ai/app's Actions policy "Only the
  # organization's members run deploys" closes that: on backend-cd.yml,
  # app-cd.yml and db-reset.yml, GitHub refuses any run or re-run whose
  # starter it does not list. It lists the same ids as this, and so does
  # the policy on osiris-cd.yml in frubble-ai/osiris; change all three
  # (docs/dev-environment.md, step 18).
  dev_deployers = {
    drn1996          = 53837062
    drribeiro        = 27741006
    frubble-platform = 350026090
  }

  backend_deploy_branch_entries = [
    for pair in setproduct(
      [
        "${local.repos.backend}|${local.repos.backend}/.github/workflows/backend-cd.yml|backend-dev",
        "${local.repos.backend}|${local.repos.backend}/.github/workflows/app-cd.yml|app-dev",
      ],
      values(local.dev_deployers),
    ) : "${pair[0]}|branch|${pair[1]}"
  ]

  # The database reset is not a deploy: it stays on the `dev` branch only,
  # matched on apply_entry, exact ref included. It runs the migration job in
  # the backend's environment.
  backend_deploy_entries = [
    "${local.repos.backend}|${local.repos.backend}/.github/workflows/db-reset.yml|backend-dev|refs/heads/dev",
  ]

  # osiris-cd.yml in osiris-dev, from any branch, by the same people. The
  # Actions policy on that workflow in frubble-ai/osiris lists the same ids.
  osiris_deploy_branch_entries = [
    for pair in setproduct(
      ["${local.repos.osiris}|${local.repos.osiris}/.github/workflows/osiris-cd.yml|osiris-dev"],
      values(local.dev_deployers),
    ) : "${pair[0]}|branch|${pair[1]}"
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
  count = length(local.backend_deploy_entries) + length(local.backend_deploy_branch_entries) > 0 ? 1 : 0

  service_account_id = local.setup.backend_deploy_hub_name
  role               = "roles/iam.workloadIdentityUser"
  members = concat(
    [
      for entry in local.backend_deploy_branch_entries :
      "principalSet://iam.googleapis.com/${local.pool}/attribute.deploy_entry/${entry}"
    ],
    [
      for entry in local.backend_deploy_entries :
      "principalSet://iam.googleapis.com/${local.pool}/attribute.apply_entry/${entry}"
    ],
  )
}

resource "google_service_account_iam_binding" "osiris_deploy_trust" {
  service_account_id = local.setup.osiris_deploy_hub_name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    for entry in local.osiris_deploy_branch_entries :
    "principalSet://iam.googleapis.com/${local.pool}/attribute.deploy_entry/${entry}"
  ]
}

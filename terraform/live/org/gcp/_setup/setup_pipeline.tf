# ---------- the pipeline that plans and applies the _setup roots ----------
# This root is applied by hand exactly once: nothing else can create the pool
# and the two bindings below. From then on every _setup root is planned on
# each pull request and applied on merge, through what this file defines, and
# the hand path (.envrc.local.example) stays for that first apply and for an
# emergency.
#
# Plan runs on unreviewed pull-request code, so it gets an identity of its own
# that can read the three projects and the _setup states, and nothing else:
# no write anywhere, and every secret value denied to it in the environment
# projects. Apply becomes the bootstrap admin, the same identity a person
# uses, and only from _setup-apply.yml running inside the `setup` GitHub
# environment on dev. That environment requires a reviewer, so a merged
# change still waits for a person before it touches anything.
#
# Neither is a hub. Everything else federates to a powerless hub and then
# becomes a spoke in the project it changes, because what CI may do belongs
# with that project. These two act on the management project itself, so the
# split would add a hop and separate nothing.

locals {
  bootstrap_service_account = "frubble-bootstrap@${var.management_project_id}.iam.gserviceaccount.com"

  # Every project a _setup root reads. Not roles/viewer: every bucket carries
  # Google's convenience binding that hands project viewers legacyObjectReader,
  # so viewer on the management project would read every state file and
  # every tfplan, prefix conditions or not. The reads refresh needs are listed
  # in setup_plan_reader below instead; org policies have a role of their own.
  setup_plan_projects = merge({ org = var.management_project_id }, var.environment_projects)
  setup_plan_roles    = ["roles/orgpolicy.policyViewer"]
  setup_plan_grants = {
    for pair in setproduct(keys(local.setup_plan_projects), local.setup_plan_roles) :
    "${pair[0]}|${pair[1]}" => { project = local.setup_plan_projects[pair[0]], role = pair[1] }
  }

  # The state prefixes of the three roots, with the trailing slash so that
  # `stg/gcp/setup` does not also match a future `stg/gcp/setup-anything`.
  setup_state_prefixes = toset(["org/gcp/setup/", "stg/gcp/setup/", "prd/gcp/setup/"])
}

# Not a hub. A hub is powerless and becomes a spoke in the project it
# changes; this account reads the management project itself and nothing
# else, so it holds its reads directly, like the deploy accounts in hubs.tf
# hold their own. Who may become it is an authoritative binding: this file is
# the only owner of that list, and a member added anywhere else is a diff.
resource "google_service_account" "setup_plan" {
  account_id   = "frubble-setup-plan"
  project      = var.management_project_id
  display_name = "Terraform plan for the _setup roots. Read-only, no secret values."
  description  = "Terraform plan for the _setup roots. Read-only, no secret values."
}

resource "google_service_account_iam_binding" "setup_plan_federated" {
  service_account_id = google_service_account.setup_plan.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    for entry in local.setup_plan_entries :
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.plan_entry/${entry}"
  ]
}

# Created through the hub module at first; the move keeps the account.
moved {
  from = module.setup_plan.google_service_account.hub
  to   = google_service_account.setup_plan
}

locals {
  setup_plan_member = "serviceAccount:${google_service_account.setup_plan.email}"
}

resource "google_project_iam_member" "setup_plan_reads_org_policies" {
  for_each = local.setup_plan_grants

  project = each.value.project
  role    = each.value.role
  member  = local.setup_plan_member

  depends_on = [module.environment_project]
}

# Exactly the reads a refresh of the three roots performs, and nothing that
# touches an object. A custom role rather than roles/viewer so this identity
# is never a project viewer, which is the member Google's convenience bindings
# grant object access to on every bucket. Deny policies are here because no
# predefined role grants their read below the organization, and the bootstrap
# admin holds no organization IAM. Defined in each project because a project
# role cannot be bound outside the project that defines it.
resource "google_project_iam_custom_role" "setup_plan_reader" {
  for_each = local.setup_plan_projects

  project     = each.value
  role_id     = "frubbleSetupPlanReader"
  title       = "Frubble _setup plan reader"
  description = "The reads a plan of the _setup roots performs. No object access."
  permissions = [
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "cloudkms.keyRings.get",
    "cloudkms.cryptoKeys.get",
    "cloudkms.cryptoKeys.getIamPolicy",
    "cloudkms.cryptoKeyVersions.list",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.getIamPolicy",
    "iam.workloadIdentityPools.get",
    "iam.workloadIdentityPoolProviders.get",
    "iam.roles.get",
    "iam.denypolicies.get",
    "iam.denypolicies.list",
  ]

  depends_on = [module.environment_project]
}

resource "google_project_iam_member" "setup_plan_reads" {
  for_each = local.setup_plan_projects

  project = each.value
  role    = google_project_iam_custom_role.setup_plan_reader[each.key].id
  member  = local.setup_plan_member
}

# Read the three _setup states, and nothing else in the bucket. No lock
# write: the plan runs with -lock=false, so the grant would only let
# pull-request code forge or delete a lock an apply depends on. This is the
# one plan identity that may read a _setup state at all, and it is what
# planning those roots from a pull request costs: the states name identities
# and bindings, never a secret value.
resource "google_storage_bucket_iam_member" "setup_plan_reads_state" {
  for_each = local.setup_state_prefixes

  bucket = module.management_state.name
  role   = "roles/storage.objectViewer"
  member = local.setup_plan_member

  condition {
    title       = "only ${trimsuffix(each.value, "/")}"
    description = "Read objects under ${each.value}."
    expression  = "resource.name.startsWith('projects/_/buckets/${module.management_state.name}/objects/${each.value}')"
  }
}

resource "google_storage_bucket_iam_member" "setup_plan_lists_state" {
  bucket = module.management_state.name
  role   = "roles/storage.legacyBucketReader"
  member = local.setup_plan_member
}

# Decrypt only: the plan writes no state, so it never encrypts.
resource "google_kms_crypto_key_iam_member" "setup_plan_state_key" {
  crypto_key_id = module.management_state.kms_key_id
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = local.setup_plan_member
}

# Its own prefix of the plan store, create-only, like every other plan.
resource "google_storage_bucket_iam_member" "setup_plan_writes_plan_store" {
  bucket = module.plan_store.name
  role   = "roles/storage.objectCreator"
  member = local.setup_plan_member

  condition {
    title       = "own plan/setup-* only"
    description = "Create objects under plan/setup-<root>/ and nothing else."
    expression  = "resource.name.startsWith('${local.plan_store_objects}/plan/setup-')"
  }
}

# The bootstrap admin is created by hand before the first apply, so it is
# named here, not managed. What is managed is the complete list of federated
# paths to it, which is this one. A different role from the tokenCreator the
# people hold on it, so they keep that, which is what makes the first apply
# and an emergency apply possible.
resource "google_service_account_iam_binding" "setup_apply_becomes_bootstrap" {
  service_account_id = "projects/${var.management_project_id}/serviceAccounts/${local.bootstrap_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  members = [
    for entry in local.setup_apply_entries :
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.apply_entry/${entry}"
  ]
}

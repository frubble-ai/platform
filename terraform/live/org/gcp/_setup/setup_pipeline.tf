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
# Neither has a spoke. Everything else federates to a powerless hub and then
# becomes a spoke in the project it changes, because what CI may do belongs
# with that project. These two act on the management project itself, so the
# split would add a hop and separate nothing.

locals {
  bootstrap_service_account = "frubble-bootstrap@${var.management_project_id}.iam.gserviceaccount.com"

  # Every project a _setup root reads. roles/viewer alone misses org policies,
  # which refresh reads; deny policies are covered at the organization below.
  setup_plan_projects = merge({ org = var.management_project_id }, var.environment_projects)
  setup_plan_roles    = ["roles/viewer", "roles/orgpolicy.policyViewer"]
  setup_plan_grants = {
    for pair in setproduct(keys(local.setup_plan_projects), local.setup_plan_roles) :
    "${pair[0]}|${pair[1]}" => { project = local.setup_plan_projects[pair[0]], role = pair[1] }
  }

  # The state prefixes of the three roots, with the trailing slash so that
  # `stg/gcp/setup` does not also match a future `stg/gcp/setup-anything`.
  setup_state_prefixes = toset(["org/gcp/setup/", "stg/gcp/setup/", "prd/gcp/setup/"])
}

module "setup_plan" {
  source = "../../../../modules/gcp/wif-hub"

  project_id  = var.management_project_id
  name        = "frubble-setup-plan"
  description = "Terraform plan for the _setup roots. Read-only, no secret values."

  pool_name      = google_iam_workload_identity_pool.github.name
  attribute      = "plan_entry"
  allowed_values = local.setup_plan_entries
}

resource "google_project_iam_member" "setup_plan_reads" {
  for_each = local.setup_plan_grants

  project = each.value.project
  role    = each.value.role
  member  = module.setup_plan.member

  depends_on = [module.environment_project]
}

# What roles/viewer misses for a read-only refresh of these roots. Reading a
# deny policy needs iam.denypolicies.get, which no predefined role grants
# below the organization: denyReviewer binds there or not at all, and the
# bootstrap admin holds no organization IAM. Reading a bucket's IAM policy
# needs storage.buckets.getIamPolicy, which viewer leaves out. Both go in a
# custom role, defined in each project because a project role cannot be bound
# outside the project that defines it. Read-only; it reveals who is denied
# and who is granted what, which this repository already states.
resource "google_project_iam_custom_role" "setup_plan_reader" {
  for_each = local.setup_plan_projects

  project     = each.value
  role_id     = "frubbleSetupPlanReader"
  title       = "Frubble _setup plan reader"
  description = "The reads roles/viewer misses for a plan of the _setup roots: deny policies and bucket IAM."
  permissions = [
    "iam.denypolicies.get",
    "iam.denypolicies.list",
    "storage.buckets.getIamPolicy",
  ]

  depends_on = [module.environment_project]
}

resource "google_project_iam_member" "setup_plan_reads_the_rest" {
  for_each = local.setup_plan_projects

  project = each.value
  role    = google_project_iam_custom_role.setup_plan_reader[each.key].id
  member  = module.setup_plan.member
}

# Read the three _setup states and write only their locks: the same split as
# every other plan identity (state_access.tf). This is the one plan identity
# that may read a _setup state at all, and it is what planning those roots
# from a pull request costs: the states name identities and bindings, never a
# secret value.
resource "google_storage_bucket_iam_member" "setup_plan_reads_state" {
  for_each = local.setup_state_prefixes

  bucket = module.management_state.name
  role   = "roles/storage.objectViewer"
  member = module.setup_plan.member

  condition {
    title       = "only ${trimsuffix(each.value, "/")}"
    description = "Read objects under ${each.value}."
    expression  = "resource.name.startsWith('projects/_/buckets/${module.management_state.name}/objects/${each.value}')"
  }
}

resource "google_storage_bucket_iam_member" "setup_plan_writes_lock" {
  for_each = local.setup_state_prefixes

  bucket = module.management_state.name
  role   = "roles/storage.objectAdmin"
  member = module.setup_plan.member

  condition {
    title       = "${trimsuffix(each.value, "/")} lock only"
    description = "The .tflock object under ${each.value}, and nothing else."
    expression  = "resource.name.startsWith('projects/_/buckets/${module.management_state.name}/objects/${each.value}') && resource.name.endsWith('.tflock')"
  }
}

resource "google_storage_bucket_iam_member" "setup_plan_lists_state" {
  bucket = module.management_state.name
  role   = "roles/storage.legacyBucketReader"
  member = module.setup_plan.member
}

resource "google_kms_crypto_key_iam_member" "setup_plan_state_key" {
  crypto_key_id = module.management_state.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = module.setup_plan.member
}

# Its own prefix of the plan store, create-only, like every other plan.
resource "google_storage_bucket_iam_member" "setup_plan_writes_plan_store" {
  bucket = module.plan_store.name
  role   = "roles/storage.objectCreator"
  member = module.setup_plan.member

  condition {
    title       = "own plan/setup-* only"
    description = "Create objects under plan/setup-<root>/ and nothing else."
    expression  = "resource.name.startsWith('${local.plan_store_objects}/plan/setup-')"
  }
}

# The bootstrap admin is created by hand before the first apply, so it is
# named here, not managed. What is managed is the one federated path to it.
# Additive: the people who hold tokenCreator on it keep that, which is what
# makes the first apply and an emergency apply possible.
resource "google_service_account_iam_member" "setup_apply_becomes_bootstrap" {
  service_account_id = "projects/${var.management_project_id}/serviceAccounts/${local.bootstrap_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.apply_entry/${one(local.setup_apply_entries)}"
}

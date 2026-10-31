# ---------- plan: reads everything, changes nothing ----------
# It still needs to write: Terraform's GCS backend takes a lock by writing an
# object, and a plan that cannot release its lock wedges every run after it.
module "plan_spoke" {
  source = "../../../../modules/gcp/wif-spoke"

  project_id  = var.project_id
  name        = "frubble-plan"
  description = "Terraform plan for ${var.environment}. Read-only, no secret values."
  hub_member  = local.plan_hub

  roles = [
    { role = "roles/viewer" },
  ]
}

# Read the state, write only the lock.
#
# objectAdmin over the whole bucket, as this was, let the plan spoke overwrite
# or delete the state objects themselves — and pull-request code reaches that
# identity through the shared plan workflow. The deny policy does not cover it:
# it denies bucket operations, not object ones.
resource "google_storage_bucket_iam_member" "plan_reads_state" {
  bucket = module.state.name
  role   = "roles/storage.objectViewer"
  member = module.plan_spoke.member
}

# The one write a plan genuinely needs. Terraform's GCS backend takes its lock
# by creating <prefix>/<workspace>.tflock and releases it by deleting that
# object, and a plan that cannot release its lock wedges every run after it.
resource "google_storage_bucket_iam_member" "plan_writes_lock" {
  bucket = module.state.name
  role   = "roles/storage.objectAdmin"
  member = module.plan_spoke.member

  condition {
    title       = "lock objects only"
    description = "Terraform's lock object, and nothing else in the bucket."
    expression  = "resource.name.endsWith('.tflock')"
  }
}

resource "google_kms_crypto_key_iam_member" "plan_state_key" {
  crypto_key_id = module.state.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = module.plan_spoke.member
}

# Refreshing an IAP tunnel binding needs iap.tunnelInstances.getIamPolicy, and
# that permission sits only in roles/iap.admin and roles/iap.settingsAdmin —
# both of which can also write. roles/viewer does not carry it, so without
# this the first plan after the tunnel grants are applied fails on refresh.
#
# A custom role with the one permission keeps plan read-only. getIamPolicy
# reads an access rule; it does not read a secret and it grants no tunnel.
resource "google_project_iam_custom_role" "iap_policy_reader" {
  project     = var.project_id
  role_id     = "frubbleIapPolicyReader"
  title       = "Frubble IAP policy reader"
  description = "Read the IAM policy of an IAP tunnel instance. Held by the plan spoke so refresh works without granting write."
  permissions = ["iap.tunnelInstances.getIamPolicy"]
}

resource "google_project_iam_member" "plan_reads_iap_policy" {
  project = var.project_id
  role    = google_project_iam_custom_role.iap_policy_reader.id
  member  = module.plan_spoke.member
}

# ---------- apply: changes infrastructure, not itself ----------
module "apply_spoke" {
  source = "../../../../modules/gcp/wif-spoke"

  project_id  = var.project_id
  name        = "frubble-apply"
  description = "Terraform apply for ${var.environment}."
  hub_member  = local.apply_hub

  roles = [
    # compute.admin also covers the load balancer and its Cloud Armor policy.
    { role = "roles/compute.admin" },
    { role = "roles/artifactregistry.admin" },
    { role = "roles/secretmanager.admin" },
    { role = "roles/iap.admin" },
    { role = "roles/serviceusage.serviceUsageAdmin" },

    # The API's Cloud Run service, the load balancer's certificate and the
    # alert policies in front of it.
    { role = "roles/run.admin" },
    { role = "roles/certificatemanager.editor" },
    { role = "roles/monitoring.editor" },

    # Project-level bindings are part of applying the stack (the instance
    # needs logWriter), but projectIamAdmin unconditionally would let the
    # apply grant itself owner. The condition limits it to the exact roles
    # this stack binds, so a request to grant anything else is refused by IAM
    # rather than caught in review.
    {
      role  = "roles/resourcemanager.projectIamAdmin"
      title = "only the roles this stack binds"
      expression = join("", [
        "api.getAttribute('iam.googleapis.com/modifiedGrantsByRole', [])",
        ".hasOnly(['roles/logging.logWriter', 'roles/monitoring.metricWriter'])",
      ])
    },

  ]
}

resource "google_storage_bucket_iam_member" "apply_state" {
  bucket = module.state.name
  role   = "roles/storage.objectAdmin"
  member = module.apply_spoke.member
}

resource "google_kms_crypto_key_iam_member" "apply_state_key" {
  crypto_key_id = module.state.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = module.apply_spoke.member
}

# ---------- tunnel-token writer: one secret, nothing else ----------
# Exists so the tunnel token never passes through Terraform. The deploy job
# fetches it from Cloudflare and writes it here; an identity that can write
# exactly one secret is a far smaller thing to leak than a state file holding
# the value in clear text.
module "tunnel_token_writer" {
  source = "../../../../modules/gcp/wif-spoke"

  project_id  = var.project_id
  name        = "frubble-tunnel-token"
  description = "Writes new versions of the tunnel-token secret. Nothing else."
  hub_member  = local.tunnel_token_hub
}

# ---------- the application's deploy spoke ----------
# Same shape as the Terraform spokes, so there is one story for how CI reaches
# a cloud rather than two. Project-level roles live here; the bindings that
# name a specific registry or instance are in the workload root, which is
# where those resources exist.
module "deploy_spoke" {
  count  = var.environment == "stg" ? 1 : 0
  source = "../../../../modules/gcp/wif-spoke"

  project_id  = var.project_id
  name        = "frubble-deploy"
  description = "frubble-app deploy: push an image, roll out the API instance."
  hub_member  = local.backend_deploy_hub

  roles = [
    # osAdminLogin rather than osLogin: the rollout runs a script with sudo,
    # and plain osLogin lands on the box without it.
    #
    # The tunnel grant is not here. It is bound on the instance, in the
    # workload root, so a second VM in this zone is not reachable by the
    # deploy — see `deploy_tunnels` there.
    { role = "roles/compute.osAdminLogin" },
  ]
}

# ---------- plan: reads everything, changes nothing ----------
resource "google_project_iam_custom_role" "pubsub_policy_viewer" {
  project     = var.project_id
  role_id     = "frubblePubsubPolicyViewer"
  title       = "Pub/Sub policy viewer"
  description = "Read the IAM policy of a topic or subscription, and nothing else."
  permissions = [
    "pubsub.topics.getIamPolicy",
    "pubsub.subscriptions.getIamPolicy",
  ]
}

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
    # viewer stops short of a topic's or subscription's IAM policy, which the
    # queue's bindings are refreshed from on every plan. No predefined role
    # reads those without writing them or reading every policy in the
    # project, so the two permissions are a role of their own.
    { role = google_project_iam_custom_role.pubsub_policy_viewer.id },
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
    { role = "roles/serviceusage.serviceUsageAdmin" },

    # The API's Cloud Run service, the load balancer's certificate and the
    # alert policies in front of it.
    { role = "roles/run.admin" },
    { role = "roles/certificatemanager.editor" },
    { role = "roles/monitoring.editor" },

    # The database, its private-IP peering and the email queue. What a
    # workload may do with them is bound on each resource, never on the
    # project, so the projectIamAdmin condition below stays as narrow as it is.
    { role = "roles/cloudsql.admin" },
    { role = "roles/servicenetworking.networksAdmin" },
    { role = "roles/pubsub.admin" },

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
  description = "frubble-app deploy: push an image, run the migration job, roll out the API and worker services."
  hub_member  = local.backend_deploy_hub

  # No project role. What the deploy may touch is bound on the registry, the
  # job and the services, in the workload root.
  roles = []
}

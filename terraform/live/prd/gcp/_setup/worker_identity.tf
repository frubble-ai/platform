# The identities behind email delivery. Same rule as api_identity.tf: created
# here, bound in the workload root.

# Runs the worker service on Cloud Run. It sends email and nothing else, so it
# never sees the database.
resource "google_service_account" "worker" {
  account_id   = "frubble-${var.environment}-worker"
  project      = var.project_id
  display_name = "frubble ${var.environment} worker"
  description  = "Runs the email worker service on Cloud Run."
}

resource "google_service_account_iam_member" "apply_attaches_worker" {
  service_account_id = google_service_account.worker.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.apply_spoke.member
}

resource "google_service_account_iam_member" "deploy_acts_as_worker" {
  count = var.environment == "stg" ? 1 : 0

  service_account_id = google_service_account.worker.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.deploy_spoke[0].member
}

# The identity Pub/Sub presents when it pushes a message to the worker. It
# holds only the invoker binding on that service; Pub/Sub's own service agent
# mints its tokens, a grant Google makes when the API is enabled.
resource "google_service_account" "push" {
  account_id   = "frubble-${var.environment}-push"
  project      = var.project_id
  display_name = "frubble ${var.environment} push"
  description  = "Caller identity of the Pub/Sub push subscriptions."
}

# Creating a push subscription that authenticates as this account is an actAs
# on the account.
resource "google_service_account_iam_member" "apply_attaches_push" {
  service_account_id = google_service_account.push.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.apply_spoke.member
}

# The identities osiris runs as. Same rule as api_identity.tf: created here,
# bound in the workload root.

# Runs the public API and the migration job.
resource "google_service_account" "osiris" {
  account_id   = "frubble-${var.environment}-osiris"
  project      = var.project_id
  display_name = "frubble ${var.environment} osiris"
  description  = "Runs the osiris API service and the migration job."
}

resource "google_service_account_iam_member" "apply_attaches_osiris" {
  service_account_id = google_service_account.osiris.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.apply_spoke.member
}

resource "google_service_account_iam_member" "deploy_acts_as_osiris" {
  service_account_id = google_service_account.osiris.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.osiris_deploy_spoke.member
}

# Runs the worker. It does not read the API key or the admin key.
resource "google_service_account" "osiris_worker" {
  account_id   = "frubble-${var.environment}-osiris-worker"
  project      = var.project_id
  display_name = "frubble ${var.environment} osiris worker"
  description  = "Runs the osiris worker service."
}

resource "google_service_account_iam_member" "apply_attaches_osiris_worker" {
  service_account_id = google_service_account.osiris_worker.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.apply_spoke.member
}

resource "google_service_account_iam_member" "deploy_acts_as_osiris_worker" {
  service_account_id = google_service_account.osiris_worker.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.osiris_deploy_spoke.member
}

# The identity Cloud Tasks presents when it calls the worker. Serve and the
# worker mint each task's OIDC token as this account, so both need actAs.
resource "google_service_account" "osiris_tasks" {
  account_id   = "frubble-${var.environment}-osiris-tasks"
  project      = var.project_id
  display_name = "frubble ${var.environment} osiris tasks"
  description  = "Caller identity of osiris Cloud Tasks."
}

resource "google_service_account_iam_member" "osiris_schedules_tasks" {
  for_each = toset([
    google_service_account.osiris.email,
    google_service_account.osiris_worker.email,
  ])

  service_account_id = google_service_account.osiris_tasks.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${each.value}"
}

# Runs the job that revokes cross-database CONNECT. It reads only that
# job's password, and nothing deploys it.
resource "google_service_account" "database_grants" {
  account_id   = "frubble-${var.environment}-db-grants"
  project      = var.project_id
  display_name = "frubble ${var.environment} database grants"
  description  = "Runs the database grant job."
}

resource "google_service_account_iam_member" "apply_attaches_database_grants" {
  service_account_id = google_service_account.database_grants.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.apply_spoke.member
}

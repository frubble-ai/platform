# The identity the API runs as on Cloud Run. Created here, not in the workload
# root, for the same reason as the instance identity: the apply spoke must
# never hold serviceAccountAdmin, and IAM conditions cannot narrow that role
# to one account.
resource "google_service_account" "api" {
  account_id   = "frubble-${var.environment}-api"
  project      = var.project_id
  display_name = "frubble ${var.environment} api"
  description  = "Runs the API service on Cloud Run."
}

# Attaching an identity to a service is a permission on the identity.
resource "google_service_account_iam_member" "apply_attaches_api" {
  service_account_id = google_service_account.api.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.apply_spoke.member
}

# A deploy creates a revision that runs as this account, which needs the same
# right — on this one account, not project-wide.
resource "google_service_account_iam_member" "deploy_acts_as_api" {
  count = var.environment == "stg" ? 1 : 0

  service_account_id = google_service_account.api.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.deploy_spoke[0].member
}

# The identity the web app's Cloud Run service runs as. Same rule as
# api_identity.tf: created here, bound in the workload root. It reads no
# secret and reaches no database: the app is a page that talks to the API.
resource "google_service_account" "app" {
  account_id   = "frubble-${var.environment}-app"
  project      = var.project_id
  display_name = "frubble ${var.environment} app"
  description  = "Runs the web app service on Cloud Run."
}

resource "google_service_account_iam_member" "apply_attaches_app" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.apply_spoke.member
}

# A deploy creates a revision that runs as this account.
resource "google_service_account_iam_member" "deploy_acts_as_app" {
  count = local.app_deploys ? 1 : 0

  service_account_id = google_service_account.app.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.deploy_spoke[0].member
}

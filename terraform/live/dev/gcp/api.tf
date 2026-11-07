# ---------- the API on Cloud Run, behind a Google load balancer ----------
module "api_service" {
  source = "../../../modules/gcp/cloud-run-service"

  project_id            = var.project_id
  name                  = "${local.name}-api"
  region                = var.region
  service_account_email = local.setup.api_service_account
  image                 = var.api_bootstrap_image
  env = merge(local.database_env, {
    APP_ENV         = module.shared.environment
    BETTER_AUTH_URL = "https://${module.shared.api_hostname}"
    # The browser origin that calls the API: the web app (app.tf)
    CORS_ORIGIN         = "https://${module.shared.app_hostname}"
    PUBSUB_EMAILS_TOPIC = module.emails_queue.topic
    # Where invitation links and the post-connect redirect land.
    APP_URL                  = "https://${module.shared.app_hostname}"
    COMPOSIO_AUTH_CONFIG_IDS = var.composio_auth_config_ids
    # The broker new connections go through: this environment's osiris (osiris.tf).
    OSIRIS_URL             = "https://${module.shared.osiris_hostname}"
    OSIRIS_AUTH_CONFIG_IDS = var.osiris_auth_config_ids
  })
  secret_env = merge(local.database_secret_env, {
    BETTER_AUTH_SECRET = { secret = module.secrets["auth_secret"].secret_id }
    COMPOSIO_API_KEY   = { secret = module.secrets["composio_api_key"].secret_id }
    OSIRIS_API_KEY     = { secret = module.secrets["osiris_api_key"].secret_id }
  })
  vpc = local.vpc
  # In prd a rollback takes one apply more: set this to false and apply, then
  # remove this stack as a whole (service, load balancer, armor, alerts and
  # their outputs) and apply, keeping the google-beta provider until then.
  deletion_protection = module.shared.environment == "prd"
  labels              = merge(local.labels, { component = "api" })

  # The secrets' versions and the bindings on them both exist before the
  # service does: Cloud Run checks a referenced secret when it creates the
  # revision.
  depends_on = [
    module.secrets,
    google_secret_manager_secret_iam_member.api_reads,
  ]
}

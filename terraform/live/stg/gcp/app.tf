# ---------- the web app on Cloud Run, behind the same load balancer ----------
# Next's server, on the image CI builds from the application repository. It
# talks to the API from the browser and holds nothing of its own: no secret,
# no database, no VPC. Its config is read at request time, so one image
# serves every environment.
module "app_service" {
  source = "../../../modules/gcp/cloud-run-service"

  project_id            = var.project_id
  name                  = "${local.name}-app"
  region                = var.region
  service_account_email = local.setup.app_service_account
  image                 = var.api_bootstrap_image
  # The page answers `/`; it has no health route of its own
  health_path = "/"
  env = {
    APP_ENV     = module.shared.environment
    GRAPHQL_URL = "https://${module.shared.api_hostname}/graphql"
  }
  deletion_protection = module.shared.environment == "prd"
  labels              = merge(local.labels, { component = "app" })

  lifecycle {
    enabled = var.enabled
  }
}

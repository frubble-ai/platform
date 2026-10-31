module "registry" {
  source = "../../../modules/gcp/artifact-registry"

  project_id  = var.project_id
  name        = local.name
  location    = var.region
  description = "Container images for frubble (${var.environment})"
  labels      = merge(local.labels, { component = "registry" })

  # Enough to roll back past a bad week of deploys.
  keep_recent_versions = 30
}

# ---------- the API on Cloud Run, behind a Google load balancer ----------
module "api_service" {
  source = "../../../modules/gcp/cloud-run-service"

  project_id            = var.project_id
  name                  = "${local.name}-api"
  region                = var.region
  service_account_email = local.setup.api_service_account
  image                 = var.api_bootstrap_image
  env                   = { APP_ENV = var.environment }
  # In prd a rollback takes one apply more: set this to false and apply, then
  # remove this stack as a whole (service, load balancer, armor, alerts and
  # their outputs) and apply, keeping the google-beta provider until then.
  deletion_protection = var.environment == "prd"
  labels              = merge(local.labels, { component = "api" })
}

module "armor" {
  source = "../../../modules/gcp/cloud-armor"

  project_id  = var.project_id
  name        = "${local.name}-lb"
  description = "WAF for the ${var.environment} load balancer"

  rate_limit = {
    count            = 300
    interval_seconds = 300
  }

  # No preconfigured rule sets for now; each is a monthly line item and the
  # API has no public input to protect yet. Add them here, in preview first.
}

module "load_balancer" {
  source = "../../../modules/gcp/https-load-balancer"

  project_id      = var.project_id
  name            = local.name
  default_backend = "api"
  security_policy = module.armor.self_link
  labels          = merge(local.labels, { component = "lb" })

  backends = {
    api = {
      service = module.api_service.name
      region  = var.region
      host    = var.api_hostname
    }
  }
}

module "alerts" {
  source = "../../../modules/gcp/alerts"

  project_id    = var.project_id
  name          = local.name
  email         = var.alert_email
  service_name  = module.api_service.name
  url_map_name  = module.load_balancer.url_map_name
  max_instances = module.api_service.max_instances
  labels        = merge(local.labels, { component = "alerts" })
}

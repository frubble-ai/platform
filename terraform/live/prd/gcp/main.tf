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

# The container only. Terraform never learns the value: the deploy job fetches
# the token from Cloudflare and writes a new version under the writer
# identity, so the token is absent from this state file by construction
# rather than by redaction.
module "tunnel_token" {
  source = "../../../modules/gcp/secret"

  project_id  = var.project_id
  environment = var.environment
  domain      = "cloudflare"
  name        = "tunnel-token"
  location    = var.region
  kms_key     = local.setup.secrets_key
  labels      = merge(local.labels, { component = "secret" })
}

# The writer's entire reason to exist, scoped to this one secret. secretVersionAdder
# rather than secretAccessor: it may add a version, and cannot read one back.
resource "google_secret_manager_secret_iam_member" "writer_adds_versions" {
  project   = var.project_id
  secret_id = module.tunnel_token.secret_id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = "serviceAccount:${local.setup.tunnel_token_writer}"
}

module "api" {
  source = "../../../modules/gcp/api-vm"

  project_id  = var.project_id
  name        = local.name
  region      = var.region
  zone        = var.zone
  environment = var.environment
  app_port    = var.app_port
  labels      = merge(local.labels, { component = "api" })

  service_account_email      = local.setup.instance_service_account
  tunnel_token_secret_id     = module.tunnel_token.secret_id
  artifact_registry_name     = module.registry.name
  artifact_registry_location = module.registry.location
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
  # remove the module and apply, keeping the google-beta provider until then.
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

  # Preview first: matches are logged, not blocked, until the logs show no
  # false positives. Each rule is a monthly line item. Evaluated before the
  # rate limit (module default priority).
  waf_rules = {
    "sqli-v33-stable" = { priority = 20 }
    "xss-v33-stable"  = { priority = 30 }
  }
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

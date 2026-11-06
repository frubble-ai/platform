module "armor" {
  source = "../../../modules/gcp/cloud-armor"

  project_id  = var.project_id
  name        = "${local.name}-lb"
  description = "WAF for the ${module.shared.environment} load balancer"

  rate_limit = {
    count            = 300
    interval_seconds = 300
  }

  # No preconfigured rule sets for now; each is a monthly line item and the
  # API has no public input to protect yet. Add them here, in preview first.

  lifecycle {
    enabled = var.enabled
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
      host    = module.shared.api_hostname
    }
    app = {
      service = module.app_service.name
      region  = var.region
      host    = module.shared.app_hostname
    }
    osiris = {
      service = module.osiris_service.name
      region  = var.region
      host    = module.shared.osiris_hostname
    }
  }

  lifecycle {
    enabled = var.enabled
  }
}

# The single certificate every host shared became the API's own (the
# load balancer module, one certificate per host): same name, kept.
moved {
  from = module.load_balancer.google_certificate_manager_certificate.this
  to   = module.load_balancer.google_certificate_manager_certificate.this["api"]
}

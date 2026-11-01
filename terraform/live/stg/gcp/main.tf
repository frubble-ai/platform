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
  env = merge(local.database_env, {
    APP_ENV         = var.environment
    BETTER_AUTH_URL = "https://${var.api_hostname}"
  })
  secret_env = merge(local.database_secret_env, {
    BETTER_AUTH_SECRET = { secret = module.secrets["auth_secret"].secret_id }
  })
  vpc = local.vpc
  # In prd a rollback takes one apply more: set this to false and apply, then
  # remove this stack as a whole (service, load balancer, armor, alerts and
  # their outputs) and apply, keeping the google-beta provider until then.
  deletion_protection = var.environment == "prd"
  labels              = merge(local.labels, { component = "api" })

  depends_on = [google_secret_manager_secret_iam_member.api_reads]
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

# ---------- what the application's deploy identity may touch ----------
# This registry, this service and the migration job. It cannot create a
# second service to run something else.
resource "google_artifact_registry_repository_iam_member" "deploy_pushes" {
  project    = var.project_id
  location   = module.registry.location
  repository = module.registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.setup.deploy_spoke}"
}

# run.developer on the service lets the deploy create a revision, and also
# change anything else in the template or delete the service; it carries no
# setIamPolicy. Image-only is the deploy script's discipline. Terraform
# ignores only the image, so any other change would show as drift and be
# reverted by the next apply.
resource "google_cloud_run_v2_service_iam_member" "deploy_rolls_out_api" {
  project  = var.project_id
  location = var.region
  name     = module.api_service.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${local.setup.deploy_spoke}"
}

# The deploy updates the job's image and executes it before rolling the
# service out; run.developer covers both.
resource "google_cloud_run_v2_job_iam_member" "deploy_runs_migrate" {
  project  = var.project_id
  location = var.region
  name     = module.migrate_job.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${local.setup.deploy_spoke}"
}

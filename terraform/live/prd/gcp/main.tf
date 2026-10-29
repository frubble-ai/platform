module "registry" {
  source = "../../../modules/gcp/artifact-registry"

  project_id  = var.project_id
  name        = local.name
  location    = var.region
  description = "Container images for frubble (${var.environment})"
  labels      = merge(local.labels, { component = "registry" })
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


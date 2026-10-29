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

# ---------- what the application's deploy identity may touch ----------
# Scoped to this registry and this instance. The deploy can publish an image
# and restart the box; it cannot create a second instance to run something
# else, and it cannot read the tunnel token the box reads at boot.
resource "google_artifact_registry_repository_iam_member" "deploy_pushes" {
  project    = var.project_id
  location   = module.registry.location
  repository = module.registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.setup.deploy_spoke}"
}

resource "google_compute_instance_iam_member" "deploy_rolls_out" {
  project       = var.project_id
  zone          = var.zone
  instance_name = module.api.instance_name
  role          = "roles/compute.instanceAdmin.v1"
  member        = "serviceAccount:${local.setup.deploy_spoke}"
}


# The deploy reaches port 22 through the same tunnel, on the same one
# instance. Its sudo rights are project-level and stay in _setup; what it may
# point them at is this.
resource "google_iap_tunnel_instance_iam_member" "deploy_tunnels" {
  project  = var.project_id
  zone     = var.zone
  instance = module.api.instance_name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "serviceAccount:${local.setup.deploy_spoke}"
}

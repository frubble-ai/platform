module "registry" {
  source = "../../../modules/gcp/artifact-registry"

  project_id  = var.project_id
  name        = local.name
  location    = var.region
  description = "Container images for frubble (${module.shared.environment})"
  labels      = merge(local.labels, { component = "registry" })

  # Enough to roll back past a bad week of deploys.
  keep_recent_versions = 30
}

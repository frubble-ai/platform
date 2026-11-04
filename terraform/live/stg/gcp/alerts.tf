module "alerts" {
  source = "../../../modules/gcp/alerts"

  project_id    = var.project_id
  name          = local.name
  email         = var.alert_email
  service_name  = module.api_service.name
  url_map_name  = module.load_balancer.url_map_name
  max_instances = module.api_service.max_instances
  labels        = merge(local.labels, { component = "alerts" })

  lifecycle {
    enabled = var.enabled
  }
}

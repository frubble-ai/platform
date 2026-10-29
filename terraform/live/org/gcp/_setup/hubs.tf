# ---------- GCP: a plan hub and an apply hub per environment ----------
# A hub holds no permissions. Its only capability is granted by the spoke in
# the environment project, which trusts this hub and nothing else.

module "plan_hub" {
  for_each = var.environment_projects
  source   = "../../../../modules/gcp/wif-hub"

  project_id  = var.management_project_id
  name        = "frubble-${each.key}-plan-hub"
  description = "CI plan entry point for ${each.key}"

  pool_name      = google_iam_workload_identity_pool.github.name
  attribute      = "plan_entry"
  allowed_values = local.plan_entries
}

module "apply_hub" {
  for_each = var.environment_projects
  source   = "../../../../modules/gcp/wif-hub"

  project_id  = var.management_project_id
  name        = "frubble-${each.key}-apply-hub"
  description = "CI apply entry point for ${each.key}"

  pool_name      = google_iam_workload_identity_pool.github.name
  attribute      = "apply_entry"
  allowed_values = local.apply_entries[each.key]
}

# ---------- the application's deploy identity ----------
# Same shape as the others: the backend federates to a hub here, and the spoke
# that lets it push images and roll out the VM lives in the stg project.
module "backend_deploy_hub" {
  source = "../../../../modules/gcp/wif-hub"

  project_id  = var.management_project_id
  name        = "frubble-stg-deploy-hub"
  description = "frubble-app deploy entry point"

  pool_name      = google_iam_workload_identity_pool.github.name
  attribute      = "apply_entry"
  allowed_values = local.backend_deploy_entries
}

module "tunnel_token_hub" {
  for_each = local.tunnel_token_entries
  source   = "../../../../modules/gcp/wif-hub"

  project_id  = var.management_project_id
  name        = "frubble-${each.key}-tunnel-token-hub"
  description = "Entry point for the ${each.key} deploy step that writes the tunnel token"

  pool_name      = google_iam_workload_identity_pool.github.name
  attribute      = "apply_entry"
  allowed_values = each.value
}

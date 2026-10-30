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

# ---------- environment-scoped hubs: the account here, the trust there ----------
# The backend deploy hub and the tunnel-token hubs are each reached by one
# environment's deploy, so who may become them changes whenever that
# environment renames a workflow or a GitHub environment. The accounts stay
# in the management project, where an environment compromise cannot delete or
# repurpose them; the workload identity binding on each — the trust rule — is
# owned by that environment's workload root, which CI plans and applies. That
# turns a renamed workflow into a reviewed, planned change there instead of a
# hand apply of this root.
resource "google_service_account" "backend_deploy_hub" {
  account_id   = "frubble-stg-deploy-hub"
  project      = var.management_project_id
  display_name = "frubble-app deploy entry point"
  description  = "frubble-app deploy entry point"
}

# One per environment, like every other hub. A single shared hub would mean
# prd's writer trusts a claim that names stg-cd.yml — so a stg deploy could
# become prd's writer and overwrite production's tunnel secret.
resource "google_service_account" "tunnel_token_hub" {
  for_each = var.environment_projects

  account_id   = "frubble-${each.key}-tunnel-token-hub"
  project      = var.management_project_id
  display_name = "Entry point for the ${each.key} deploy step that writes the tunnel token"
  description  = "Entry point for the ${each.key} deploy step that writes the tunnel token"
}

# The accounts were created through the hub module. These keep them as they
# are rather than replacing them, which would change their unique ids and
# break every binding that names them.
moved {
  from = module.backend_deploy_hub.google_service_account.hub
  to   = google_service_account.backend_deploy_hub
}

moved {
  from = module.tunnel_token_hub["stg"].google_service_account.hub
  to   = google_service_account.tunnel_token_hub["stg"]
}

moved {
  from = module.tunnel_token_hub["prd"].google_service_account.hub
  to   = google_service_account.tunnel_token_hub["prd"]
}

# Their trust bindings leave this state without being destroyed. The
# environment roots create the same bindings (trust.tf there), which leaves
# each hub's policy as it is because the member is already in it, so at no
# point is a deploy identity untrusted.
removed {
  from = module.backend_deploy_hub.google_service_account_iam_member.federated

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.tunnel_token_hub.google_service_account_iam_member.federated

  lifecycle {
    destroy = false
  }
}

# What an environment's apply spoke may do to its hubs: read and set the whole
# IAM policy of each hub account. setIamPolicy cannot be narrowed to one
# binding, so this is more than the trust rule: the holder could also grant
# itself token creation on the hub. What bounds it is the hub, not the role —
# a hub holds no permissions, and this environment's hubs can only become this
# environment's deploy spoke and tunnel-token writer, both of which the apply
# spoke already outranks inside the project. Not serviceAccountAdmin, which
# would also let it delete the account or change what it is. Defined in this
# project because a custom role can only be bound on resources of the project
# that defines it, and the hubs are here. Bound per hub by the environment's
# _setup root, never project-wide.
resource "google_project_iam_custom_role" "hub_trust_editor" {
  project     = var.management_project_id
  role_id     = "frubbleHubTrustEditor"
  title       = "Frubble hub trust editor"
  description = "Read and set the whole IAM policy of one hub service account. Bounded by the hub holding nothing itself."
  permissions = [
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.setIamPolicy",
  ]
}

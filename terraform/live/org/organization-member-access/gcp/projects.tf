module "project" {
  for_each = var.environment_projects
  source   = "../../../../modules/gcp/member-access"

  project_id      = each.value
  org_id          = var.org_id
  developer_group = var.developer_group

  members = {
    for handle, p in local.people : handle => { member = p.member, profiles = p.gcp[each.key] }
    if length(p.gcp[each.key]) > 0
  }

  allowed_members = distinct(concat(local.always_allowed, [
    for p in values(local.people) : p.member if length(p.gcp[each.key]) > 0
  ]))

  depends_on = [google_org_policy_policy.no_domain_rule]
}

# Created by org/gcp/_setup before this root took it over: stg's and prd's.
# dev's project came after the move, so its policy is created here, not
# imported.
import {
  for_each = { for env, project in var.environment_projects : env => project if contains(["stg", "prd"], env) }

  to = module.project[each.key].google_iam_deny_policy.no_secret_values
  id = "${urlencode("cloudresourcemanager.googleapis.com/projects/${each.value}")}/frubble-developers-no-secret-values"
}

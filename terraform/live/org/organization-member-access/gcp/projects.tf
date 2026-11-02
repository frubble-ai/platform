# Each environment gets only the people with a profile there, and allows only
# them, the administrator and the developer group.
module "project" {
  for_each = var.environment_projects
  source   = "../../../../modules/gcp/member-access"

  project_id = each.value
  org_id     = var.org_id

  members = {
    for handle, p in local.people : handle => { member = p.member, profiles = p.gcp[each.key] }
    if length(p.gcp[each.key]) > 0
  }

  allowed_members = distinct(concat(local.always_allowed, [
    for p in values(local.people) : p.member if length(p.gcp[each.key]) > 0
  ]))

  depends_on = [google_org_policy_policy.no_domain_rule]
}

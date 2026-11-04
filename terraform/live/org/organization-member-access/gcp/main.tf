locals {
  people = {
    for handle, p in jsondecode(var.org_members_access) : handle => {
      # Google names a person by their account's primary address.
      member = "user:${lower(trimspace(try(p.gcp.account, p.email)))}"
      gcp    = { for env in keys(var.environment_projects) : env => try(p.gcp[env], []) }
    }
  }

  always_allowed = [var.administrator, var.developer_group]
}

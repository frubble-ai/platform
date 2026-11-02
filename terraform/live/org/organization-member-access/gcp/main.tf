locals {
  people = {
    for handle, p in jsondecode(var.org_members_access) : handle => {
      member = "user:${lower(trimspace(p.email))}"
      gcp    = { stg = try(p.gcp.stg, []), prd = try(p.gcp.prd, []) }
    }
  }

  always_allowed = [var.administrator, var.developer_group]
}

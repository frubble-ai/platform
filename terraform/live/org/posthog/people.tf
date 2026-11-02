# The decoded ORG_MEMBERS_ACCESS (variables.tf), with every field present.
locals {
  people = {
    for handle, p in jsondecode(var.org_members_access) : handle => {
      email   = lower(trimspace(p.email))
      gcp     = { stg = try(p.gcp.stg, []), prd = try(p.gcp.prd, []) }
      posthog = try(p.posthog, null)
    }
  }
}

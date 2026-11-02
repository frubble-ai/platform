# Everyone in ORG_MEMBERS_ACCESS (variables.tf) with a PostHog level.
locals {
  members = {
    for handle, p in jsondecode(var.org_members_access) : handle => {
      email = lower(trimspace(p.email))
      level = p.posthog
    } if try(p.posthog, null) != null
  }
}

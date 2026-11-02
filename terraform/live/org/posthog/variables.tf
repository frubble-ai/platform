variable "organization_id" {
  description = "UUID of the frubble organization. Sign-up creates it; Terraform never does."
  type        = string
}

variable "owner_email" {
  description = <<-EOT
    Email of the organization owner account, which Terraform never manages.
    Used only to reject it in members. CI supplies it from the
    POSTHOG_OWNER_EMAIL secret; no address is written in this repository.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.owner_email)) > 0
    error_message = "owner_email is empty. Set the POSTHOG_OWNER_EMAIL secret (or owner_email in a local tfvars)."
  }
}

variable "org_members_access" {
  description = <<-EOT
    The organization's people and what each may do, keyed by a short handle,
    never an address. One entry per person covers every system: `gcp` lists
    profiles per environment (modules/gcp/developer-access), `posthog` is a
    level (member or admin). CI supplies it from the ORG_MEMBERS_ACCESS secret as JSON:
    {"alex":{"email":"...","gcp":{"stg":["administration"]},"posthog":"member"}}
    The same list is all of README "Human access".
  EOT
  type = map(object({
    email = string
    gcp = optional(object({
      stg = optional(list(string), [])
      prd = optional(list(string), [])
    }), {})
    posthog = optional(string)
  }))
  default   = {}
  sensitive = true

  validation {
    condition     = alltrue([for k in nonsensitive(keys(var.org_members_access)) : can(regex("^[a-z][a-z0-9_-]{0,31}$", k))])
    error_message = "Each key must be a short handle: lowercase letters, digits, - or _, starting with a letter, at most 32 characters."
  }

  validation {
    condition     = alltrue([for p in values(var.org_members_access) : p.posthog == null || contains(["member", "admin"], p.posthog)])
    error_message = "posthog must be member or admin. The owner account is not managed here."
  }

  # PostHog rejects any change to one's own level, even a no-op, so listing the
  # owner would bring back the apply failure main.tf's removed block avoids.
  validation {
    condition     = alltrue([for p in values(var.org_members_access) : p.posthog == null || lower(trimspace(p.email)) != lower(trimspace(var.owner_email))])
    error_message = "The owner account is not managed here; give it no posthog level."
  }
}

variable "organization_id" {
  type = string
}

# The owner holds the apply key and PostHog refuses a change to one's own level.
variable "owner_email" {
  type      = string
  sensitive = true

  validation {
    condition     = length(trimspace(var.owner_email)) > 0
    error_message = "Set POSTHOG_OWNER_EMAIL."
  }
}

variable "org_members_access" {
  description = "The ORG_MEMBERS_ACCESS JSON, decoded in main.tf."
  type        = string
  sensitive   = true

  validation {
    condition     = can(keys(jsondecode(var.org_members_access)))
    error_message = "Must be a JSON object keyed by handle."
  }

  validation {
    condition     = alltrue([for k in nonsensitive(keys(try(jsondecode(var.org_members_access), {}))) : can(regex("^[a-z][a-z0-9_-]{0,31}$", k))])
    error_message = "Each key must be a short lowercase handle."
  }

  validation {
    condition = alltrue([
      for p in values(try(jsondecode(var.org_members_access), {})) :
      can(regex("^[^@\\s]+@[^@\\s]+$", p.email))
      && length(setsubtract(keys(p), ["email", "gcp", "posthog"])) == 0
      && length(setsubtract(keys(try(p.gcp, {})), ["account", "dev", "stg", "prd"])) == 0
      && (try(p.posthog, null) == null ? true : contains(["member", "admin"], p.posthog))
    ])
    error_message = "Each entry takes email, gcp (account, dev, stg, prd) and posthog (member or admin) only."
  }

  validation {
    condition = length(distinct([
      for p in values(try(jsondecode(var.org_members_access), {})) : lower(trimspace(p.email))
    ])) == length(try(jsondecode(var.org_members_access), {}))
    error_message = "Each email may appear once."
  }

  validation {
    condition = alltrue([
      for p in values(try(jsondecode(var.org_members_access), {})) :
      try(p.posthog, null) == null || lower(trimspace(p.email)) != lower(trimspace(var.owner_email))
    ])
    error_message = "The PostHog owner gets no posthog level."
  }
}

variable "organization_id" {
  type = string
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
      && length(setsubtract(keys(try(p.gcp, {})), ["stg", "prd"])) == 0
      && (try(p.posthog, null) == null ? true : contains(["member", "admin"], p.posthog))
    ])
    error_message = "Each entry takes email, gcp (stg, prd) and posthog (member or admin) only."
  }

  validation {
    condition = length(distinct([
      for p in values(try(jsondecode(var.org_members_access), {})) : lower(trimspace(p.email))
    ])) == length(try(jsondecode(var.org_members_access), {}))
    error_message = "Each email may appear once."
  }
}

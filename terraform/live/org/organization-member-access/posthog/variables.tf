variable "organization_id" {
  description = "UUID of the frubble organization. Sign-up creates it; Terraform never does."
  type        = string
}

variable "owner_email" {
  description = <<-EOT
    Email of the organization owner account, which Terraform never manages.
    Used only to refuse it a level. CI supplies it from the
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
    The organization's people and what each may do, as the JSON the
    ORG_MEMBERS_ACCESS secret holds (README, "Human access"): keyed by a short
    handle, never an address; per person an `email`, `gcp` profiles per
    environment and a `posthog` level (member or admin). Taken as a string and decoded in main.tf, so a misspelled key fails
    the plan instead of being dropped, and an unset secret fails instead of
    reading as nobody.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = can(keys(jsondecode(var.org_members_access)))
    error_message = "Must be a JSON object keyed by handle."
  }

  validation {
    condition     = alltrue([for k in nonsensitive(keys(try(jsondecode(var.org_members_access), {}))) : can(regex("^[a-z][a-z0-9_-]{0,31}$", k))])
    error_message = "Each key must be a short handle: lowercase letters, digits, - or _, starting with a letter, at most 32 characters."
  }

  validation {
    condition = alltrue([
      for p in values(try(jsondecode(var.org_members_access), {})) :
      can(regex("^[^@\\s]+@[^@\\s]+$", p.email))
      && length(setsubtract(keys(p), ["email", "gcp", "posthog"])) == 0
      && length(setsubtract(keys(try(p.gcp, {})), ["stg", "prd"])) == 0
      && (try(p.posthog, null) == null ? true : contains(["member", "admin"], p.posthog))
    ])
    error_message = "Each person needs an `email` and may have only `gcp` (with `stg` and `prd`) and `posthog` (member or admin)."
  }

  validation {
    condition = length(distinct([
      for p in values(try(jsondecode(var.org_members_access), {})) : lower(trimspace(p.email))
    ])) == length(try(jsondecode(var.org_members_access), {}))
    error_message = "Each email may appear once."
  }

  # PostHog rejects any change to one's own level, even a no-op, so a level on
  # the owner would fail every apply (org/posthog/main.tf).
  validation {
    condition = alltrue([
      for p in values(try(jsondecode(var.org_members_access), {})) :
      try(p.posthog, null) == null || lower(trimspace(p.email)) != lower(trimspace(var.owner_email))
    ])
    error_message = "The owner account is not managed here; give it no posthog level."
  }
}

variable "org_id" {
  description = "The organization's numeric id."
  type        = string
}

variable "management_project_id" {
  description = "The management project, where the provider bills its calls."
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "environment_projects" {
  description = "Project id per environment."
  type        = map(string)
}

variable "administrator" {
  description = "The one account with administration everywhere (org/gcp/_setup), as `user:address`. Always allowed."
  type        = string
}

variable "developer_group" {
  description = "The read-only developer group (org/gcp/_setup), as `group:address`. Always allowed."
  type        = string
}

variable "org_members_access" {
  description = <<-EOT
    The organization's people and what each may do, as the JSON the
    ORG_MEMBERS_ACCESS secret holds (README, "Human access"): keyed by a short
    handle, never an address; per person an `email`, `gcp` profiles per
    environment (modules/gcp/member-access) and a `posthog` level (member or
    admin). Taken as a string and decoded in main.tf, so a misspelled key fails
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

  # Two resources for one grant: removing either would revoke it for both.
  validation {
    condition = alltrue([
      for p in values(try(jsondecode(var.org_members_access), {})) :
      "user:${lower(trimspace(p.email))}" != lower(var.administrator)
    ])
    error_message = "The administrator already holds administration everywhere; leave them out of ORG_MEMBERS_ACCESS."
  }
}

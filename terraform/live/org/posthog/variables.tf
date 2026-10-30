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
}

variable "members" {
  description = <<-EOT
    Human members of the organization and their level, keyed by a short handle.
    Each must already have joined (main.tf explains why). Level is member or
    admin; the owner account is never listed.

    CI supplies it from the POSTHOG_MEMBERS secret as JSON:
    {"daniel":{"email":"...","level":"admin"}}

    Handles appear in resource addresses, and so in plan output: lowercase
    letters, digits, "-" or "_", starting with a letter, at most 32
    characters. A name, never an email or an id.
  EOT
  type = map(object({
    email = string
    level = string
  }))
  default   = {}
  sensitive = true

  validation {
    condition     = alltrue([for k in keys(var.members) : can(regex("^[a-z][a-z0-9_-]{0,31}$", k))])
    error_message = "Each members key must be a short handle: lowercase letters, digits, - or _, starting with a letter, at most 32 characters."
  }

  validation {
    condition     = alltrue([for m in values(var.members) : contains(["member", "admin"], m.level)])
    error_message = "Level must be member or admin. The owner account is not managed here."
  }

  # PostHog rejects any change to one's own level, even a no-op, so listing the
  # owner would bring back the apply failure main.tf's removed block avoids.
  validation {
    condition     = alltrue([for m in values(var.members) : lower(trimspace(m.email)) != lower(trimspace(var.owner_email))])
    error_message = "The owner account is not managed here; remove it from members."
  }
}

variable "organization_id" {
  description = "UUID of the frubble organization. Sign-up creates it; Terraform never does."
  type        = string
}

variable "members" {
  description = <<-EOT
    Human members of the organization and their level, keyed by a short handle:
    { daniel = { email = "...", level = "admin" } }. Each must already have
    joined (main.tf explains why). Level is member or admin; owner stays with
    platform@frubble.ai, which this map never names.

    Supplied by CI from the POSTHOG_MEMBERS repository variable as JSON, never
    written in this repository: it is public, and so are its plan comments.
  EOT
  type = map(object({
    email = string
    level = string
  }))
  default   = {}
  sensitive = true

  validation {
    condition     = alltrue([for m in values(var.members) : contains(["member", "admin"], m.level)])
    error_message = "Level must be member or admin. Owner is held by platform@frubble.ai and is not managed here."
  }
}

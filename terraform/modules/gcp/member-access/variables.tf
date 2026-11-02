variable "project_id" {
  description = "Environment project the members get access to."
  type        = string
}

variable "members" {
  description = <<-EOT
    The organization's people with access to this project, keyed by a short
    handle: each an IAM member (`user:address`) and the profiles (main.tf,
    local.profiles) it holds here. The handle, never the address, is what a
    resource key shows.
  EOT
  type = map(object({
    member   = string
    profiles = list(string)
  }))
  sensitive = true

  validation {
    condition     = alltrue([for m in values(var.members) : startswith(m.member, "user:")])
    error_message = "Each member must be one person, `user:address`: a group's managers would decide who holds the access."
  }

  validation {
    condition     = alltrue([for m in values(var.members) : alltrue([for p in m.profiles : contains(["read_only", "administration", "logs"], p)])])
    error_message = "Unknown profile. The profiles are read_only, administration and logs (main.tf, local.profiles)."
  }
}

variable "allowed_members" {
  description = <<-EOT
    Every person and group that may hold a role in this project, besides what
    the organization makes itself: the members above, the administrator and
    the developer group. Enforced on the project, so someone allowed in one
    environment cannot be granted a role in another.
  EOT
  type        = list(string)
  sensitive   = true
}

variable "org_id" {
  description = "The organization, whose principal set admits its own service accounts, workload identity pools and service agents."
  type        = string
}

variable "project_id" {
  description = "Environment project the developers get access to."
  type        = string
}

variable "group" {
  description = <<-EOT
    The developer group, as an IAM member string. Either a Workspace group or a
    consumer Google group — IAM accepts both, as `group:address`. Membership is
    managed in the group, not here, so adding or removing a person is not a
    code change and not a deploy.
  EOT
  type        = string

  validation {
    condition     = startswith(var.group, "group:")
    error_message = "Must be a group, written as `group:address`. Naming a person directly would make every access change a pull request."
  }
}

variable "administrator" {
  description = <<-EOT
    The one person who may change this project outside CI, as `user:address`.
    A single account rather than a group, so every out-of-band change has one
    owner. Passed in rather than written here: who holds it is a fact about the
    organization, not a property of the code.
  EOT
  type        = string

  validation {
    condition     = startswith(var.administrator, "user:")
    error_message = "Must be one person, written as `user:address`. A group here would remove the single owner this role exists to give."
  }
}

variable "additional_administrators" {
  description = <<-EOT
    Other people given the same administration role, as `user:address`, keyed
    by a short handle. The handle, never the address, is what a resource key
    and a public plan show. Empty by default: the administrator above stays
    the owner, and these are for a project that needs more hands.
  EOT
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.additional_administrators) : can(regex("^[a-z][a-z0-9_-]{0,31}$", k))])
    error_message = "Each key must be a short handle: lowercase letters, digits, - or _, starting with a letter, at most 32 characters."
  }

  validation {
    condition     = alltrue([for m in values(var.additional_administrators) : startswith(m, "user:")])
    error_message = "Each must be one person, written as `user:address`."
  }
}

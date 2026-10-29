variable "project_id" {
  description = "Environment project the spoke acts in. The spoke exists inside the blast radius it is allowed to touch."
  type        = string
}

variable "name" {
  description = "Service account id, e.g. `frubble-apply`."
  type        = string
}

variable "description" {
  description = "What this spoke is for."
  type        = string
}

variable "hub_member" {
  description = "The one member allowed to mint tokens for this spoke, as `serviceAccount:...`. Set authoritatively: anything else holding that right is removed on apply."
  type        = string
}

variable "roles" {
  description = <<-EOT
    Roles granted to the spoke on its own project. `condition` narrows a role to
    a subset of resources — used to keep a broad role like projectIamAdmin from
    reaching resources outside this stack's naming prefix.
  EOT
  type = list(object({
    role       = string
    title      = optional(string)
    expression = optional(string)
  }))
  default = []

  validation {
    condition     = length([for r in var.roles : r if(r.expression == null) != (r.title == null)]) == 0
    error_message = "A conditional role needs both `title` and `expression`; an unconditional one needs neither. A condition with no title is silently dropped by the API."
  }
}

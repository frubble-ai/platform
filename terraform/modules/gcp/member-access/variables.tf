variable "project_id" {
  type = string
}

variable "org_id" {
  type = string
}

variable "developer_group" {
  type = string
}

variable "members" {
  description = "Handle to { member = \"user:...\", profiles = [...] }."
  type = map(object({
    member   = string
    profiles = list(string)
  }))
  sensitive = true

  validation {
    condition     = alltrue([for m in values(var.members) : startswith(m.member, "user:")])
    error_message = "Each member must be a person, `user:address`."
  }

  validation {
    condition     = alltrue([for m in values(var.members) : alltrue([for p in m.profiles : contains(["read_only", "administration", "logs"], p)])])
    error_message = "Profiles are read_only, administration and logs."
  }
}

variable "allowed_members" {
  type      = list(string)
  sensitive = true
}

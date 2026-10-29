variable "expected_project_id" {
  description = "The project this root is allowed to act on. Stated by the root itself, not read from the environment, so a wrong workflow input cannot also move the target."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.expected_project_id))
    error_message = "Not a syntactically valid project id. A typo here would otherwise be caught only after the provider had already started making calls."
  }
}

variable "additional_allowed_projects" {
  description = <<-EOT
    Projects whose service accounts may also run this root. `_setup` roots name
    the management project here, because the bootstrap admin lives there and
    applies every environment — without this the pin would refuse the one use
    it was designed for. CI roots leave it empty, so their credential must come
    from the project they are changing and nowhere else.
  EOT
  type        = list(string)
  default     = []
}

variable "allow_user_credentials" {
  description = <<-EOT
    Whether a human credential may run this root. A user credential carries no
    project in its identity, so the pin cannot be checked against it — the
    check can only be skipped. `_setup` roots are applied by a person and set
    this true; every CI root leaves it false, which is what makes a
    human-credentialed run of a CI root fail instead of silently proceeding.
  EOT
  type        = bool
  default     = false
}

variable "organization_id" {
  description = "UUID of the frubble organization. Sign-up creates it; Terraform never does."
  type        = string
}

variable "administrator_email" {
  description = <<-EOT
    The person who administers the organization. They must already be a
    member: PostHog cannot invite through the API, so the invitation is sent
    by hand and this root only raises the accepted member to admin.
  EOT
  type        = string
}

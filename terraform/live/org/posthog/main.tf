# One project for every environment. The environment travels on the data —
# deployment.environment.name on traces, environment on log lines — so stg and
# prd are filters, not projects to keep in sync.
#
# Sign-up created this project under a placeholder name; it is adopted rather
# than replaced so its API token, and anything already sending with it, keeps
# working. Once applied the import block is a no-op.
import {
  to = posthog_project.frubble
  id = "${var.organization_id}/695513"
}

resource "posthog_project" "frubble" {
  name     = "frubble"
  timezone = "UTC"
}

data "posthog_user" "administrator" {
  email = var.administrator_email
}

# retain_on_destroy: by default, destroying this resource removes the person
# from the organization. Taking it out of Terraform should stop managing their
# level, not lock them out.
resource "posthog_organization_member" "administrator" {
  user_uuid         = data.posthog_user.administrator.uuid
  level             = "admin"
  retain_on_destroy = true
}

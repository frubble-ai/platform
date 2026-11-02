# One project for every environment. The environment travels on the data —
# deployment.environment.name on traces, environment on log lines — so stg and
# prd are filters, not projects to keep in sync.
#
# Sign-up created this project under a placeholder name; it is adopted rather
# than replaced so its API token, and anything already sending with it, keeps
# working. Once applied the import block is a no-op.
import {
  to = posthog_project.frubble
  id = "${var.organization_id}/697540"
}

resource "posthog_project" "frubble" {
  name     = "frubble"
  timezone = "UTC"
}

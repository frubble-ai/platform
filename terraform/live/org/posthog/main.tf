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

# The owner account's membership is not managed here. It is the organization
# owner from sign-up, and PostHog refuses any change to one's
# own level ("You can't change your own access level"), even a no-op, so the
# resource could never apply with platform's own key. Dropped from state only;
# the membership itself stays as it is.
removed {
  from = posthog_organization_member.administrator

  lifecycle {
    destroy = false
  }
}

# ---------- the people ----------
# Members and their levels moved to org/organization-member-access/posthog,
# applied from the ORG_MEMBERS_ACCESS list (README, "Human access"). Dropped
# from this state only; that root adopts every membership again.
removed {
  from = posthog_organization_member.member

  lifecycle {
    destroy = false
  }
}

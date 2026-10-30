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
# Humans are members at the level `var.members` gives them. The owner account
# is deliberately not among them (see `removed` above).
#
# The provider has no invite resource: posthog_organization_member only adopts
# someone who has already joined. So a person reaches this map in two steps:
#   1. Invite them from PostHog → Settings → Members, as the owner account,
#      and wait for them to accept.
#   2. Add them to the POSTHOG_MEMBERS repository secret (a JSON object) under
#      a short handle, e.g.
#      {"daniel":{"email":"...","level":"admin"},"alex":{"email":"...","level":"member"}}
#      and merge.
#      The import below adopts the existing membership instead of changing
#      it, and from then on their level is whatever the map says.
# Someone in the map who has not joined fails the plan at the user lookup,
# which is the point: the map can only describe people who exist.
#
# Keyed by handle, never by email: plans are posted on pull requests of a
# public repository, and a key is printed in every resource address.
data "posthog_user" "member" {
  for_each = toset(nonsensitive(keys(var.members)))

  email = var.members[each.key].email
}

import {
  for_each = toset(nonsensitive(keys(var.members)))

  to = posthog_organization_member.member[each.key]
  id = "${var.organization_id}/${data.posthog_user.member[each.key].uuid}"
}

# retain_on_destroy: taking someone out of the map stops managing their level;
# it does not remove them from the organization. Removing a person is done in
# PostHog, on purpose, by the owner.
resource "posthog_organization_member" "member" {
  for_each = toset(nonsensitive(keys(var.members)))

  user_uuid         = data.posthog_user.member[each.key].uuid
  level             = var.members[each.key].level
  retain_on_destroy = true
}

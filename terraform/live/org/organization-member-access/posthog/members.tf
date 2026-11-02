# Members at the level ORG_MEMBERS_ACCESS gives them. The owner account is
# never among them (org/posthog/main.tf).
#
# The provider has no invite resource: posthog_organization_member only adopts
# someone who has already joined. So a person reaches PostHog in two steps:
#   1. The owner invites them from PostHog → Settings → Members, and they
#      accept.
#   2. They get a `posthog` level in ORG_MEMBERS_ACCESS, and
#      organization-member-access-cd runs.
# Someone with a level who has not joined fails the plan at the user lookup:
# the list can only describe people who exist.
#
# The list is the whole truth: someone taken out of it, or whose level is
# removed, is removed from the organization on the next apply.
#
# Keyed by handle, never by email: a key is printed in every resource address.
data "posthog_user" "member" {
  for_each = toset(nonsensitive(keys(local.members)))

  email = local.members[each.key].email
}

# Adopts each existing membership rather than creating it.
import {
  for_each = toset(nonsensitive(keys(local.members)))

  to = posthog_organization_member.member[each.key]
  id = "${var.organization_id}/${data.posthog_user.member[each.key].uuid}"
}

resource "posthog_organization_member" "member" {
  for_each = toset(nonsensitive(keys(local.members)))

  user_uuid         = data.posthog_user.member[each.key].uuid
  level             = local.members[each.key].level
  retain_on_destroy = false
}

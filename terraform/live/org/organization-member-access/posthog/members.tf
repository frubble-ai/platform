# Adopts people who already joined; the provider cannot invite.
data "posthog_user" "member" {
  for_each = toset(nonsensitive(keys(local.members)))

  email = local.members[each.key].email
}

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

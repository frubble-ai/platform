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
# Moved to org/organization-member-access/posthog.
removed {
  from = posthog_organization_member.member

  lifecycle {
    destroy = false
  }
}

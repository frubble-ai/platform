# ---------- who may be granted a role ----------
# A fixed list, not a domain. The organization is two people, and neither
# needs a Workspace seat to work in it, so "anyone in frubble.ai" would both
# refuse the people who do the work and admit anyone given a seat later.
#
# Organization-wide: the administrator, the developer group and everyone in
# ORG_MEMBERS_ACCESS. Each environment project narrows it to the people with
# access there (modules/gcp/member-access). The organization principal set
# admits what the organization makes itself: service accounts and workload
# identity pools in its projects, and its service agents. allUsers and
# allAuthenticatedUsers stay refused.
resource "google_org_policy_policy" "allowed_members" {
  name   = "organizations/${var.org_id}/policies/iam.managed.allowedPolicyMembers"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
      parameters = jsonencode({
        allowedMemberSubjects = distinct(concat(local.always_allowed, [for p in values(local.people) : p.member]))
        allowedPrincipalSets  = ["//cloudresourcemanager.googleapis.com/organizations/${var.org_id}"]
      })
    }
  }
}

# The domain rule this replaces was set by hand when the organization was
# created. Adopted, then lifted, and only once the list above is enforced.
import {
  to = google_org_policy_policy.no_domain_rule
  id = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
}

resource "google_org_policy_policy" "no_domain_rule" {
  name   = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      allow_all = "TRUE"
    }
  }

  depends_on = [google_org_policy_policy.allowed_members]
}

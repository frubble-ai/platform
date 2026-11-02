# Only listed people and groups, plus the organization's own identities, may hold a role.
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

# The hand-set domain rule, lifted once the list above is enforced.
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

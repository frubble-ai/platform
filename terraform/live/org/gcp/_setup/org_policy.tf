# The state buckets name a customer-managed key, so writes that say nothing
# land encrypted under it. That is a default, not a rule: a caller can still
# ask for Google-managed encryption explicitly, and nothing refuses.
#
# This is what refuses. The constraint rejects creating a Cloud Storage
# resource that does not use a customer-managed key, which turns "unencrypted
# writes are unlikely" into "unencrypted writes are impossible".
#
# Scoped per project rather than set at the organization, because the
# organization still contains the pre-rebuild project, and a bucket there was
# created without CMEK.
resource "google_org_policy_policy" "management_requires_cmek" {
  name   = "projects/${var.management_project_id}/policies/gcp.restrictNonCmekServices"
  parent = "projects/${var.management_project_id}"

  spec {
    rules {
      values {
        denied_values = ["storage.googleapis.com"]
      }
    }
  }

  depends_on = [google_project_service.management_orgpolicy]
}

resource "google_project_service" "management_orgpolicy" {
  project = var.management_project_id
  service = "orgpolicy.googleapis.com"

  disable_on_destroy = false
}

# ---------- who may be granted a role ----------
# A fixed list, not a domain. The organization is two people, and neither
# needs a Workspace seat to work in it, so "anyone in frubble.ai" would both
# refuse the people who do the work and admit anyone given a seat later.
#
# People and groups are named one by one: administrator, developer_group and
# everyone in var.access (the TF_SETUP_ACCESS secret). The organization principal set admits
# what the organization makes itself: service accounts and workload identity
# pools in its projects, and its service agents. allUsers and
# allAuthenticatedUsers stay refused.
resource "google_org_policy_policy" "allowed_iam_members" {
  name   = "organizations/${var.org_id}/policies/iam.managed.allowedPolicyMembers"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
      parameters = jsonencode({
        allowedMemberSubjects = distinct(concat([var.administrator, var.developer_group], [for person in values(var.access) : person.member]))
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

  depends_on = [google_org_policy_policy.allowed_iam_members]
}

locals {
  profiles = {
    read_only = ["roles/viewer"]
    administration = [
      "roles/editor",
      "roles/resourcemanager.projectIamAdmin",
      "roles/secretmanager.secretAccessor",
    ]
    logs = ["roles/logging.viewer"]
  }

  grants = {
    for grant in flatten([
      for handle, profiles in nonsensitive({ for h, m in var.members : h => m.profiles }) : [
        for profile in profiles : [
          for role in local.profiles[profile] : { key = "${handle}|${profile}|${role}", handle = handle, role = role }
        ]
      ]
    ]) : grant.key => grant
  }

  denied = concat(
    [replace(var.developer_group, "group:", "principalSet://goog/group/")],
    [for m in values(var.members) : "principal://goog/subject/${trimprefix(m.member, "user:")}" if !contains(m.profiles, "administration")],
  )
  spared = [
    for m in values(var.members) : "principal://goog/subject/${trimprefix(m.member, "user:")}"
    if contains(m.profiles, "administration")
  ]
}

resource "google_org_policy_policy" "allowed_members" {
  name   = "projects/${var.project_id}/policies/iam.managed.allowedPolicyMembers"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
      parameters = jsonencode({
        allowedMemberSubjects = var.allowed_members
        allowedPrincipalSets  = ["//cloudresourcemanager.googleapis.com/organizations/${var.org_id}"]
      })
    }
  }
}

resource "google_project_iam_member" "member" {
  for_each = local.grants

  project = var.project_id
  role    = each.value.role
  member  = var.members[each.value.handle].member

  depends_on = [google_org_policy_policy.allowed_members]
}

# No secret values for the group or anyone without administration.
resource "google_iam_deny_policy" "no_secret_values" {
  parent       = urlencode("cloudresourcemanager.googleapis.com/projects/${var.project_id}")
  name         = "frubble-developers-no-secret-values"
  display_name = "Developers may see that a secret exists, never its value"

  rules {
    deny_rule {
      denied_principals    = local.denied
      exception_principals = local.spared
      denied_permissions   = ["secretmanager.googleapis.com/versions.access"]
    }
  }
}

# What a person may do in a project is a list of profiles, each a fixed set of
# roles. A new kind of access is a new profile here (and in the list
# variables.tf validates against), reviewed like any change; who holds it is
# data, kept out of the repository (README, "Human access").
locals {
  profiles = {
    # Sees everything, changes nothing, never a secret's value (the deny below).
    read_only = ["roles/viewer"]

    # The administrator's role (modules/gcp/developer-access), for one project.
    administration = [
      "roles/editor",
      "roles/resourcemanager.projectIamAdmin",
      "roles/secretmanager.secretAccessor",
    ]

    # Reads the logs, nothing else.
    logs = ["roles/logging.viewer"]
  }

  # Handles and profiles are not secret; the addresses are.
  grants = {
    for grant in flatten([
      for handle, profiles in nonsensitive({ for h, m in var.members : h => m.profiles }) : [
        for profile in profiles : [
          for role in local.profiles[profile] : { key = "${handle}|${profile}|${role}", handle = handle, role = role }
        ]
      ]
    ]) : grant.key => grant
  }

  # The developer group and everyone without administration are refused
  # secret values. People with administration are spared, even as members of
  # the group.
  denied = concat(
    [replace(var.developer_group, "group:", "principalSet://goog/group/")],
    [for m in values(var.members) : "principal://goog/subject/${trimprefix(m.member, "user:")}" if !contains(m.profiles, "administration")],
  )
  spared = [
    for m in values(var.members) : "principal://goog/subject/${trimprefix(m.member, "user:")}"
    if contains(m.profiles, "administration")
  ]
}

resource "google_project_iam_member" "member" {
  for_each = local.grants

  project = var.project_id
  role    = each.value.role
  member  = var.members[each.value.handle].member

  depends_on = [google_org_policy_policy.allowed_members]
}

# Deny beats allow, always and everywhere: a role granted by hand later still
# reads no value. Created by modules/gcp/developer-access, adopted here (the
# root's import), since only this list knows who must be spared.
resource "google_iam_deny_policy" "no_secret_values" {
  parent       = urlencode("cloudresourcemanager.googleapis.com/projects/${var.project_id}")
  name         = "frubble-developers-no-secret-values"
  display_name = "Developers may see that a secret exists, never its value"

  rules {
    deny_rule {
      denied_principals    = local.denied
      exception_principals = local.spared
      denied_permissions = [
        "secretmanager.googleapis.com/versions.access",
      ]
    }
  }
}

# Who may hold a role here at all, by name. Overrides the organization's list
# for this project only.
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

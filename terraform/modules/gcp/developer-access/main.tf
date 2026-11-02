# Human access to an environment project, in two shapes: a group that may look
# and one person who may act. Nobody gets a shell on the VM — reaching the box
# means reaching the box's identity, which reads a secret, so the two roles
# below are the whole of what a person may do here.

# ---------- role 1: read-only ----------
# `viewer` is the broad "see everything" role. It deliberately does not grant
# secretmanager.versions.access, but it does grant enough adjacent permissions
# that relying on that absence is a bet on Google never widening the role. The
# deny policy below turns it into a guarantee.
resource "google_project_iam_member" "read_only" {
  project = var.project_id
  role    = "roles/viewer"
  member  = var.group
}

# Deny beats allow, always and everywhere. Even if someone later grants this
# group secretAccessor by hand, reading a value stays refused until this
# policy is edited — and editing it shows up as a diff here.
resource "google_iam_deny_policy" "no_secret_values" {
  parent       = urlencode("cloudresourcemanager.googleapis.com/projects/${var.project_id}")
  name         = "frubble-developers-no-secret-values"
  display_name = "Developers may see that a secret exists, never its value"

  rules {
    deny_rule {
      denied_principals = [replace(var.group, "group:", "principalSet://goog/group/")]
      denied_permissions = [
        "secretmanager.googleapis.com/versions.access",
      ]
    }
  }
}

# ---------- role 2: administration ----------
# Named people, never a group, and deliberately not behind the deny above.
# Every change made outside CI therefore has a named owner, which is the
# point: an incident asks "who did this", and the answer cannot be "somebody in
# a group". `administrator` is the one who holds it everywhere; a project that
# needs more hands names them in `additional_administrators`.
#
# Broad on purpose, because this role exists for the cases nobody listed in
# advance — a stuck lock, a half-applied change, a resource CI cannot reach.
#
# Not roles/owner, though, because owner cannot be granted this way. Google's
# setIamPolicy refuses to make a *user* an owner: that goes through the
# console's invitation, which the person has to accept. The apply fails on
# this one binding and creates everything around it, so the role silently does
# not exist — which is what happened here, and why the org state held a
# read-only binding for each project and no administration binding at all.
#
# editor does everything to resources, and projectIamAdmin adds managing who
# has access. Together they are owner without two things nobody needs from
# here: deleting the project and moving its billing.
#
# secretAccessor because neither of those reads a secret's value — editor
# manages secrets but not their payloads. Owner would have included it, and a
# recovery that needs a secret's value should not start with granting it.
locals {
  administration_roles = toset([
    "roles/editor",
    "roles/resourcemanager.projectIamAdmin",
    "roles/secretmanager.secretAccessor",
  ])
}

resource "google_project_iam_member" "administration" {
  for_each = local.administration_roles

  project = var.project_id
  role    = each.value
  member  = var.administrator
}

# The same role for the additional administrators, keyed `handle|role`.
resource "google_project_iam_member" "additional_administration" {
  for_each = {
    for pair in setproduct(keys(var.additional_administrators), local.administration_roles) :
    "${pair[0]}|${pair[1]}" => { member = var.additional_administrators[pair[0]], role = pair[1] }
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

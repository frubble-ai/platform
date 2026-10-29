# One project per environment — the hard wall. A stg credential has no path to
# prd, so isolation does not depend on every IAM binding being right.
module "environment_project" {
  for_each = var.environment_projects
  source   = "../../../../modules/gcp/project"

  project_id      = each.value
  name            = "frubble ${each.key}"
  org_id          = var.org_id
  billing_account = var.billing_account
  apis            = var.apis

  labels = {
    env          = each.key
    component    = "project"
    "managed-by" = "terraform"
  }
}

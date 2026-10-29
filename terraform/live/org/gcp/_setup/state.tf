# Holds the state of this root, of every other _setup root, and of the
# Cloudflare roots. Environment workload state lives in that environment's own
# bucket instead, so a credential that can read stg's workload state still
# cannot read the identities that granted it.
module "management_state" {
  source = "../../../../modules/gcp/state-bucket"

  name       = "${var.management_project_id}-tfstate"
  project_id = var.management_project_id
  location   = var.region

  labels = {
    env          = "org"
    component    = "state"
    "managed-by" = "terraform"
  }
}

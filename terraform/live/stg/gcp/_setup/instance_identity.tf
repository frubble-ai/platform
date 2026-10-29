# The identity the VM runs as is created here, not in the workload root.
#
# It was in the workload root, which forced the apply spoke to hold
# serviceAccountAdmin. That role cannot be narrowed: IAM conditions can only
# read resource.name for services that publish it, and iam.googleapis.com does
# not. A condition naming frubble-${var.environment}-vm therefore evaluates
# false and grants nothing, while an unconditioned grant would let the apply
# identity edit every service account in the project, its own spokes included.
#
# Creating it alongside the spokes removes the dilemma: the apply identity
# never needs to create a service account, so it never needs the role.
resource "google_service_account" "instance" {
  account_id   = "frubble-${var.environment}-vm"
  project      = var.project_id
  display_name = "frubble ${var.environment} instance"
  description  = "Runs the API container and the tunnel connector."
}

# Attaching an identity to a VM is a permission on the identity, not on the
# VM. Without this the apply fails at instance creation with a message about
# the service account rather than about the instance.
resource "google_service_account_iam_member" "apply_attaches_instance" {
  service_account_id = google_service_account.instance.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.apply_spoke.member
}

# `gcloud compute ssh` acts as the instance's own identity, so the deploy
# needs this too — on this one account, not project-wide.
resource "google_service_account_iam_member" "deploy_acts_as_instance" {
  count = var.environment == "stg" ? 1 : 0

  service_account_id = google_service_account.instance.name
  role               = "roles/iam.serviceAccountUser"
  member             = module.deploy_spoke[0].member
}

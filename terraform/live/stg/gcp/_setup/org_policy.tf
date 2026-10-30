# See the equivalent file in org/gcp/_setup: the bucket's default key makes
# unencrypted writes unlikely, and this constraint makes them impossible.
resource "google_org_policy_policy" "requires_cmek" {
  name   = "projects/${var.project_id}/policies/gcp.restrictNonCmekServices"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      values {
        denied_values = ["storage.googleapis.com"]
      }
    }
  }

  depends_on = [google_project_service.orgpolicy]
}

# The one VM may hold an external IP, and nothing else in the project may.
#
# This organization was created with Google's secure-by-default organization
# policies, one of which sets compute.vmExternalIpAccess to deny all. The
# instance in stg/gcp needs an ephemeral address for egress only: pulling its
# image and dialling out to the Cloudflare edge. Nothing inbound can use it;
# the firewall denies all ingress except Google's IAP range (.trivyignore.yaml,
# AVD-GCP-0031). Cloud NAT would avoid the address, and is the one cost this
# stack is designed not to carry.
#
# The exception names the instance, not the project, so a second VM here still
# gets no address. The zone and name mirror the stg/gcp defaults; changing
# either there means changing this value too.
resource "google_org_policy_policy" "vm_external_ip" {
  name   = "projects/${var.project_id}/policies/compute.vmExternalIpAccess"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      values {
        allowed_values = ["projects/${var.project_id}/zones/us-central1-a/instances/frubble-${var.environment}"]
      }
    }
  }

  depends_on = [google_project_service.orgpolicy]
}

resource "google_project_service" "orgpolicy" {
  project = var.project_id
  service = "orgpolicy.googleapis.com"

  disable_on_destroy = false
}

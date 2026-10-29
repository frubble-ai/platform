variable "org_id" {
  description = "Organization that owns every project this root creates."
  type        = string
}

variable "billing_account" {
  description = "Billing account the new projects attach to. It does not have to live in the organization; the applying identity only needs billing.user on it."
  type        = string
}

variable "management_project_id" {
  description = <<-EOT
    Project that holds the management state bucket, the identity pool and the
    hubs. Created by hand during bootstrap, because this root stores its own
    state in a bucket inside it — the chicken-and-egg has to be broken
    somewhere, and a single hand-made project is the smallest place to do it.
  EOT
  type        = string
}

variable "environment_projects" {
  description = "Project id per environment. Stated explicitly rather than generated: these ids are the hard wall between environments and appear in every trust rule."
  type        = map(string)

  validation {
    condition     = alltrue([for e in ["stg", "prd"] : contains(keys(var.environment_projects), e)])
    error_message = "Both stg and prd must be present. prd is created even though nothing is applied to it, so that its plan runs against a real project."
  }
}

variable "region" {
  description = "Default region for the management project's resources."
  type        = string
  default     = "us-central1"
}

variable "github_owner" {
  description = "GitHub organization owning both repositories."
  type        = string
}

variable "platform_repository" {
  description = "Repository holding this Terraform."
  type        = string
}

variable "backend_repository" {
  description = "Repository holding the application."
  type        = string
}

variable "developer_group" {
  description = <<-EOT
    Group granted the read-only role on stg and prd, as `group:address`. IAM
    accepts both Workspace groups and consumer googlegroups.com addresses. The
    group is created by hand: Google exposes no API for creating consumer
    groups, and this organization has no directory for the Cloud Identity API
    to write into.
  EOT
  type        = string
}

variable "administrator" {
  description = <<-EOT
    The one account granted the administration role on stg and prd, as
    `user:address`. Full access, used for what CI cannot do, and held by one
    person so every out-of-band change has an owner.
  EOT
  type        = string
}

variable "apis" {
  description = "APIs enabled on every environment project."
  type        = list(string)
  default = [
    "compute.googleapis.com",

    # Not optional, though nothing in Terraform calls it. Both containers on
    # the VM run with Docker's gcplogs driver, which pings Cloud Logging when
    # the container is created and refuses to start it if the ping fails — so
    # with this API off, neither the application nor cloudflared ever runs,
    # and both units restart forever without reaching the edge.
    "logging.googleapis.com",

    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "iap.googleapis.com",
    "oslogin.googleapis.com",
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]
}

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

variable "org_members_access" {
  description = <<-EOT
    The organization's people and what each may do, as the JSON the
    ORG_MEMBERS_ACCESS secret holds (README, "Human access"): keyed by a short
    handle, never an address; per person an `email`, `gcp` profiles per
    environment (modules/gcp/developer-access) and a `posthog` level (member or
    admin). Taken as a string and decoded here, so a misspelled key fails the
    plan instead of being dropped, and an unset secret fails instead of
    reading as nobody.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = can(tomap(jsondecode(var.org_members_access)))
    error_message = "Must be a JSON object keyed by handle."
  }

  validation {
    condition     = alltrue([for k in nonsensitive(keys(try(jsondecode(var.org_members_access), {}))) : can(regex("^[a-z][a-z0-9_-]{0,31}$", k))])
    error_message = "Each key must be a short handle: lowercase letters, digits, - or _, starting with a letter, at most 32 characters."
  }

  validation {
    condition = alltrue([
      for p in values(try(jsondecode(var.org_members_access), {})) :
      can(regex("^[^@\\s]+@[^@\\s]+$", p.email))
      && length(setsubtract(keys(p), ["email", "gcp", "posthog"])) == 0
      && length(setsubtract(keys(try(p.gcp, {})), ["stg", "prd"])) == 0
      && contains(["member", "admin", "none"], try(p.posthog, "none"))
    ])
    error_message = "Each person needs an `email` and may have only `gcp` (with `stg` and `prd`) and `posthog` (member or admin)."
  }

  validation {
    condition = length(distinct([
      for p in values(try(jsondecode(var.org_members_access), {})) : lower(trimspace(p.email))
    ])) == length(try(jsondecode(var.org_members_access), {}))
    error_message = "Each email may appear once."
  }

  # Two resources for one grant: removing either would revoke it for both.
  validation {
    condition = alltrue([
      for p in values(try(jsondecode(var.org_members_access), {})) :
      "user:${lower(trimspace(p.email))}" != lower(var.administrator)
    ])
    error_message = "The administrator already holds administration everywhere; leave them out of ORG_MEMBERS_ACCESS."
  }
}

variable "apis" {
  description = "APIs enabled on every environment project."
  type        = list(string)
  default = [
    "compute.googleapis.com",

    # Cloud Run writes the services' logs here.
    "logging.googleapis.com",

    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",

    # The API runs as a Cloud Run service behind a load balancer whose
    # certificate Certificate Manager issues; Monitoring holds its alerts.
    "run.googleapis.com",
    "certificatemanager.googleapis.com",
    "monitoring.googleapis.com",

    # The database is a private-IP Cloud SQL instance reached over a Service
    # Networking peering; the email worker is fed by a Pub/Sub push
    # subscription.
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "pubsub.googleapis.com",

    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    # Creating a service's own identity (Pub/Sub's, for dead-lettering) is a
    # Service Usage call.
    "serviceusage.googleapis.com",
  ]
}

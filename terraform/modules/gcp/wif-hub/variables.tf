variable "project_id" {
  description = "Management project holding the hub. Hubs live outside the environments they reach, so an environment compromise cannot edit the identity that grants access to it."
  type        = string
}

variable "name" {
  description = "Service account id, e.g. `frubble-stg-apply-hub`."
  type        = string
}

variable "description" {
  description = "What this hub is for. Shown in the IAM console next to the account."
  type        = string
}

variable "pool_name" {
  description = "Full resource name of the workload identity pool, as returned by google_iam_workload_identity_pool.name."
  type        = string
}

variable "attribute" {
  description = "Mapped attribute the trust rule selects on. This is a composite attribute built in the pool provider, so a single principalSet can require a conjunction of claims rather than just one."
  type        = string
}

variable "allowed_values" {
  description = "Values of `attribute` allowed to impersonate this hub. Each entry is a complete, exact match of every claim that matters; there is no wildcard, so a claim nobody anticipated cannot slip through."
  type        = list(string)

  validation {
    condition     = length(var.allowed_values) > 0
    error_message = "A hub with no allowed values can never be used, which fails closed but silently. State at least one entry."
  }
}

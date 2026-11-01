variable "project_id" {
  description = "Project that owns the secret."
  type        = string
}

variable "environment" {
  description = "Environment segment of the name, e.g. `stg`."
  type        = string
}

variable "domain" {
  description = "What the secret belongs to, e.g. `cloudflare`."
  type        = string
}

variable "name" {
  description = "Leaf name, e.g. `api-key`."
  type        = string
}

variable "location" {
  description = "Single region the secret is replicated to. User-managed replication is required because a customer-managed key is region-bound and automatic replication cannot use one."
  type        = string
}

variable "kms_key" {
  description = "The environment's secrets key. One key per environment, so revoking stg's key cannot lock prd out of its own secrets."
  type        = string
}

variable "labels" {
  description = "Labels applied to the secret."
  type        = map(string)
  default     = {}
}

variable "generated" {
  description = "Whether Terraform generates the value (`value_wo`) or a person adds it over a placeholder. Separate from `value_wo`, which is ephemeral and so cannot decide which resource exists."
  type        = bool
  default     = false
}

variable "value_wo" {
  description = "The generated value, written through the write-only attribute and never recorded in state. Set with `generated`."
  type        = string
  default     = null
  ephemeral   = true

  validation {
    condition     = var.generated == (var.value_wo != null)
    error_message = "value_wo is set exactly when generated is true."
  }
}

variable "value_wo_version" {
  description = "Recorded in place of the value: a change writes `value_wo` again, as a new version."
  type        = number
  default     = 1
}

variable "placeholder" {
  description = "Value written at creation when `value_wo` is null. Never the real secret: a plain attribute is recorded in state, and state is readable by everyone who can read the bucket."
  type        = string
  default     = "REPLACE_ME_VIA_SECRET_MANAGER"
}

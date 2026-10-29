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
  description = "Leaf name, e.g. `tunnel-token`."
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

variable "placeholder" {
  description = "Value written at creation. Never the real secret: whatever Terraform writes is recorded in state, and state is readable by everyone who can read the bucket."
  type        = string
  default     = "REPLACE_ME_VIA_SECRET_MANAGER"
}

variable "project_id" { type = string }

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "management_state_bucket" {
  description = "Where the _setup roots keep their state. Read-only from here."
  type        = string
}

variable "spoke_service_account" {
  description = "Spoke this run acts as. The plan workflow passes the read-only spoke, the apply workflow the write one, so the same root is harmless or not depending only on which identity CI hands it."
  type        = string
}

variable "api_bootstrap_image" {
  description = "Image the service runs until the first deploy replaces it."
  type        = string
  default     = "gcr.io/google-samples/hello-app:1.0"
}

variable "alert_email" {
  description = "Address that receives the alerts."
  type        = string
  default     = "platform@frubble.ai"
}

variable "secrets_version" {
  description = "Pins the generated secret values (the database password, the auth secret, osiris's database password, API key and admin key). Bump it to rotate them: the next apply generates new values and writes them to Secret Manager and the database; the services pick them up on their next revision. Does not rotate osiris's encryption key."
  type        = number
  default     = 1
}

variable "osiris_encryption_key_version" {
  description = "Pins OSIRIS_ENCRYPTION_KEY only. Bumping secrets_version does not rotate it: the key wraps every tenant data key, and a new value makes the stored tokens unreadable. Bump this only when the data keys are re-wrapped in the same change."
  type        = number
  default     = 1
}

variable "email_api_key_version" {
  description = "Secret Manager version of email/api-key the worker reads. Pinned, so a new provider's key added ahead of its EMAIL_PROVIDER change is not picked up by an instance still on the old provider; both move in one PR."
  type        = string
  default     = "latest"
}

variable "email_provider" {
  description = "Which email provider the worker sends through; the application knows the ones it supports. The provider's own setup (its root, its keys, the DNS records) is what docs/email.md describes."
  type        = string
  default     = "mailgun"
}

variable "composio_auth_config_ids" {
  description = "The API's Composio auth configs as `provider=id` pairs separated by commas, from the COMPOSIO_AUTH_CONFIG_IDS_<ENV> repository variable."
  type        = string
}

variable "enabled" {
  description = "Whether stg's running resources exist: the database, the services, the queue, the load balancer and what hangs off them. False destroys them on the next apply, true rebuilds them from this code. From the STG_ENABLED repository variable (docs/stg-switch.md)."
  type        = bool
  default     = true
  nullable    = false
}

variable "queue_name_suffix" {
  description = "Appended to the osiris Cloud Tasks queue's name. Cloud Tasks keeps a deleted queue's name for about a week, so rebuilding stg sooner than that after switching it off needs a new name here, e.g. \"-2\" (docs/stg-switch.md). Changing it on a running stg replaces the queue and drops its pending tasks."
  type        = string
  default     = ""
}

variable "database_instance_suffix" {
  description = "Appended to the Cloud SQL instance's name. Cloud SQL keeps a deleted instance's name for up to a week, so rebuilding stg sooner than that after switching it off needs a new name here, e.g. \"-2\" (docs/stg-switch.md). Changing it on a running stg replaces the database."
  type        = string
  default     = ""
}

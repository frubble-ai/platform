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
  description = "Pins the generated secret values (the database password, the auth secret). Bump it to rotate them: the next apply generates new values and writes them to Secret Manager and the database; the services pick them up on their next revision."
  type        = number
  default     = 1
}

variable "email_api_key_version" {
  description = "Secret Manager version of email/api-key the worker reads. Pinned, so a new provider's key added ahead of its EMAIL_PROVIDER change is not picked up by an instance still on the old provider; both move in one PR."
  type        = string
  default     = "latest"
}

variable "email_provider" {
  description = "Which email provider the worker sends through; the application knows the ones it supports. The provider's own setup (its root, its keys, the DNS records) is what the Email section of the README describes."
  type        = string
  default     = "mailgun"
}

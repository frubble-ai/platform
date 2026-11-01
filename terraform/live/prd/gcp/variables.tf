variable "project_id" { type = string }

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "environment" {
  type    = string
  default = "prd"
}

variable "management_state_bucket" {
  description = "Where the _setup roots keep their state. Read-only from here."
  type        = string
}

variable "spoke_service_account" {
  description = "Spoke this run acts as. The plan workflow passes the read-only spoke, the apply workflow the write one, so the same root is harmless or not depending only on which identity CI hands it."
  type        = string
}

variable "api_hostname" {
  description = "Public hostname of the API behind the load balancer, which replaces the tunnel's `api-<env>.<domain>` name at the cutover. The certificate and the host rule use it; the application's deploy verifies against it."
  type        = string
  default     = "api.frubble.ai"
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

variable "email_domain" {
  description = "The sending domain, registered at the email provider by the Cloudflare root. The worker sends as noreply@ it."
  type        = string
  default     = "frubble.ai"
}

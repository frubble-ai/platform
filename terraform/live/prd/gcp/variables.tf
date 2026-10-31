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

variable "app_port" {
  description = "Loopback port the application listens on."
  type        = number
  default     = 8080
}

variable "spoke_service_account" {
  description = "Spoke this run acts as. The plan workflow passes the read-only spoke, the apply workflow the write one, so the same root is harmless or not depending only on which identity CI hands it."
  type        = string
}

variable "api_hostname" {
  description = "Public hostname of the API. The load balancer's certificate and its host rule use it."
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

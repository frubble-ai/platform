variable "project_id" { type = string }
variable "name" {
  type        = string
  description = "Name prefix for every resource here, e.g. `frubble-stg`. Also the network tag the firewall rules target."
}
variable "region" { type = string }
variable "zone" { type = string }
variable "environment" { type = string }

variable "machine_type" {
  type        = string
  default     = "e2-micro"
  description = "e2-micro in us-central1/us-west1/us-east1 is covered by the always-free tier."
}

variable "boot_disk_size_gb" {
  type        = number
  default     = 10
  description = "The free tier covers 30 GB-month of pd-standard across the project."
}

variable "subnet_cidr" {
  type        = string
  default     = "10.10.0.0/24"
  description = "Private range for the subnet. Nothing routes to it from outside."
}

variable "app_port" {
  type        = number
  description = "Loopback port the application listens on. Never published; the connector reaches it from inside the box."
}

variable "tunnel_token_secret_id" {
  type        = string
  description = "Short id of the Secret Manager secret holding the tunnel token. The instance reads it at boot with its own identity, so the value is never in metadata and never in state."
}

variable "artifact_registry_name" { type = string }
variable "artifact_registry_location" { type = string }

variable "bootstrap_image" {
  type        = string
  default     = "gcr.io/google-samples/hello-app:1.0"
  description = "Image the box runs until the first deploy replaces it, so the tunnel has a live origin the moment it boots instead of a connection refused."
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "service_account_email" {
  description = "Identity the VM runs as, created in the environment's _setup root."
  type        = string
}

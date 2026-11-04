variable "management_state_bucket" {
  description = "The management bucket, where the handoff object for the Cloudflare root goes (handoff.tf)."
  type        = string
}

variable "project_id" {
  description = "The environment's GCP project, from GCP_PROJECT_<ENV>: where the sending key's secret lives (sending_key.tf)."
  type        = string
}

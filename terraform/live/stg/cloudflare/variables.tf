variable "zone_id" {
  description = "Cloudflare zone the DNS record is published in."
  type        = string
}

variable "management_state_bucket" {
  description = "The management bucket, where the other roots' handoff objects for this one are (handoff.tf)."
  type        = string
}

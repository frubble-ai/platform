variable "zone_id" {
  description = "Cloudflare zone the DNS record is published in."
  type        = string
}

variable "management_state_bucket" {
  description = "The management bucket, where the other roots' handoff objects for this one are (handoff.tf)."
  type        = string
}

variable "enabled" {
  description = "Whether stg is switched on (docs/stg-switch.md). Off, the records that point at the load balancer go with it; the email records stay, since the Mailgun domain does. From the STG_ENABLED repository variable."
  type        = bool
  default     = true
  nullable    = false
}

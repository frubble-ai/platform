variable "sending_domain" {
  description = "The domain the stg worker sends from. A subdomain of the zone, so its SPF and DMARC never touch the apex's."
  type        = string
  default     = "stg.frubble.ai"
}

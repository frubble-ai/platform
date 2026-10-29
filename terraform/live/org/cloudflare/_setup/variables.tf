variable "account_id" {
  description = "Cloudflare account the tunnel permissions are scoped to."
  type        = string
}

variable "zone_id" {
  description = "The zone every environment publishes into. The plan token's read permissions are scoped to it and to nothing else."
  type        = string
}

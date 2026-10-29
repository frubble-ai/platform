variable "zone_id" {
  description = "Cloudflare zone the record belongs to."
  type        = string
}

variable "hostname" {
  description = "Fully qualified name of the record."
  type        = string
}

variable "target" {
  description = "CNAME target, normally `<tunnel-id>.cfargotunnel.com`."
  type        = string
}

variable "comment" {
  description = "Shown in the Cloudflare dashboard. Worth filling in: a proxied CNAME to an opaque tunnel id is otherwise unidentifiable from the UI."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone the record belongs to."
  type        = string
}

variable "hostname" {
  description = "Fully qualified name of the record."
  type        = string
}

variable "type" {
  description = "Record type, `CNAME` or `A`."
  type        = string
  default     = "CNAME"

  validation {
    condition     = contains(["A", "CNAME"], var.type)
    error_message = "type must be A or CNAME."
  }
}

variable "target" {
  description = "Record content: the CNAME target, or the address of an A record."
  type        = string
}

variable "proxied" {
  description = "Through Cloudflare's edge (true) or straight to the target (false)."
  type        = bool
  default     = true
}

variable "ttl" {
  description = "TTL in seconds for a DNS-only record. Ignored when proxied."
  type        = number
  default     = 300
}

variable "comment" {
  description = "Shown in the Cloudflare dashboard. Worth filling in: a proxied CNAME to an opaque tunnel id is otherwise unidentifiable from the UI."
  type        = string
}

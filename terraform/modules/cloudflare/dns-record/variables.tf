variable "zone_id" {
  description = "Cloudflare zone the record belongs to."
  type        = string
}

variable "hostname" {
  description = "Fully qualified name of the record."
  type        = string
}

variable "type" {
  description = "Record type: `CNAME`, `A`, `TXT` or `MX`."
  type        = string
  default     = "CNAME"

  validation {
    condition     = contains(["A", "CNAME", "TXT", "MX"], var.type)
    error_message = "type must be A, CNAME, TXT or MX."
  }
}

variable "target" {
  description = "Record content: the CNAME target, the address of an A record, the text of a TXT, the mail host of an MX."
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

variable "priority" {
  description = "MX records only."
  type        = number
  default     = null
}

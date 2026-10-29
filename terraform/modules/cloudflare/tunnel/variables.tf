variable "account_id" {
  description = "Cloudflare account that owns the tunnel."
  type        = string
}

variable "name" {
  description = "Tunnel name, e.g. `frubble-stg`."
  type        = string
}

variable "hostname" {
  description = "Public hostname routed through the tunnel. Kept flat (api-stg-frubble.example.com, not api.stg.frubble.example.com) because Universal SSL covers the apex and one wildcard level only; a deeper host fails the TLS handshake outright on the Free plan."
  type        = string
}

variable "app_port" {
  description = "Port the application listens on, on the loopback interface of the origin."
  type        = number
}

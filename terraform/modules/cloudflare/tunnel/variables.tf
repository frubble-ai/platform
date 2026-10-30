variable "account_id" {
  description = "Cloudflare account that owns the tunnel."
  type        = string
}

variable "name" {
  description = "Tunnel name, e.g. `frubble-stg`."
  type        = string
}

variable "hostname" {
  description = "Public hostname routed through the tunnel."
  type        = string
}

variable "app_port" {
  description = "Port the application listens on, on the loopback interface of the origin."
  type        = number
}

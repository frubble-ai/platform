variable "account_id" {
  description = "Cloudflare account that owns the tunnel."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone the DNS record is published in."
  type        = string
}

variable "domain" {
  description = "Zone apex, e.g. `example.site`."
  type        = string
}

variable "environment" {
  type    = string
  default = "prd"
}

variable "app_port" {
  description = <<-EOT
    Port the application listens on, on the origin's loopback interface.

    Stated here rather than read from the GCP root's state. It is a constant of
    the application, not an output of that stack — and reading it across roots
    created an ordering dependency that is not real: the Cloudflare plan would
    fail on every pull request until the GCP workload had been applied once.
  EOT
  type        = number
  default     = 8080
}

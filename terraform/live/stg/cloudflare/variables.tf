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
  default = "stg"
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

variable "certificate_dns_authorization_name" {
  description = "Name of the CNAME Certificate Manager asks for, from the GCP root's output. Empty until the first GCP apply has produced it."
  type        = string
  default     = ""

  # Both or neither. One missing variable would otherwise read as "no record"
  # and the next apply would delete the one the certificate renews against.
  validation {
    condition     = (var.certificate_dns_authorization_name == "") == (var.certificate_dns_authorization_target == "")
    error_message = "certificate_dns_authorization_name and certificate_dns_authorization_target must be set together or both left empty."
  }
}

variable "certificate_dns_authorization_target" {
  description = "Its target, from the same output."
  type        = string
  default     = ""
}

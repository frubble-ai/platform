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

variable "origin_ip" {
  description = "Address of the load balancer, from the GCP root's load_balancer_ip output. Empty until the first GCP apply has produced it."
  type        = string
  default     = ""
}

variable "mailgun_dkim_name" {
  description = "Name of the DKIM TXT record, from the mailgun root's dkim_record_name output. Empty until that root has applied."
  type        = string
  default     = ""

  # Both or neither, for the reason the certificate authorization gives above.
  validation {
    condition     = (var.mailgun_dkim_name == "") == (var.mailgun_dkim_value == "")
    error_message = "mailgun_dkim_name and mailgun_dkim_value must be set together or both left empty."
  }
}

variable "mailgun_dkim_value" {
  description = "Its value, from the same root's dkim_record_value output."
  type        = string
  default     = ""
}

variable "zone_id" {
  description = "The shared zone."
  type        = string
}

variable "zone_settings" {
  description = <<-EOT
    Zone-wide security posture, as setting id to value. One zone serves stg and
    prd, so every entry here applies to both at once — which is the reason it
    goes through the pipeline rather than a hand-apply.

    Defaults are the posture, not a starting point: changing one is a reviewed
    change to this file, so the value a reviewer reads is the value that gets
    applied.
  EOT
  type        = map(string)
  default = {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    automatic_https_rewrites = "on"
    opportunistic_encryption = "on"
    tls_1_3                  = "on"
    browser_check            = "on"
  }
}

variable "records" {
  description = <<-EOT
    DNS records that belong to no environment — an apex record, a verification
    TXT, a mail route. Environment hostnames are not declared here: they are
    created by that environment's own Cloudflare root, so a change to stg's
    hostname cannot be applied by the org pipeline.

    Empty by default. The root exists so org-wide records have one obvious
    home; inventing records to fill it would be worse than leaving it empty.
  EOT
  type = map(object({
    type    = string
    content = string
    proxied = optional(bool, false)
    ttl     = optional(number, 1)
    comment = optional(string, "managed by terraform")
  }))
  default = {}
}

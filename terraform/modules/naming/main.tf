# The names an environment is known by, derived once from two facts: which
# environment, and the zone. No provider, no state: the environment's
# `shared/` module calls this and every root in that environment reads the
# result (docs/shared-values.md).
locals {
  # prd is the bare zone; every other environment is a subdomain of it.
  host_prefix = var.environment == "prd" ? "" : "${var.environment}."
}

output "environment" {
  value = var.environment
}

output "zone" {
  value = var.zone
}

output "name" {
  description = "Resource name prefix: `frubble-stg`."
  value       = "frubble-${var.environment}"
}

output "api_hostname" {
  description = "Public hostname of the API: `api.dev.frubble.ai`, `api.stg.frubble.ai`, `api.frubble.ai`."
  value       = "api.${local.host_prefix}${var.zone}"
}

output "app_hostname" {
  description = "Public hostname of the web app: `app.dev.frubble.ai`, `app.stg.frubble.ai`, `app.frubble.ai`."
  value       = "app.${local.host_prefix}${var.zone}"
}

output "osiris_hostname" {
  description = "Public hostname of osiris: `osiris.dev.frubble.ai`, `osiris.stg.frubble.ai`, `osiris.frubble.ai`."
  value       = "osiris.${local.host_prefix}${var.zone}"
}

output "sending_domain" {
  description = "Domain the worker sends from. A subdomain, never the apex, whose mail belongs to the people at it: `dev.frubble.ai`, `stg.frubble.ai`, `mail.frubble.ai`. Each environment its own, so dev never sends as stg."
  value       = var.environment == "prd" ? "mail.${var.zone}" : "${var.environment}.${var.zone}"
}

output "labels" {
  description = "Base labels. `component` is added at each module call."
  value = {
    env          = var.environment
    "managed-by" = "terraform"
  }
}

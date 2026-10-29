locals {
  # Flat, not api.stg.frubble.<domain>. Universal SSL covers the apex and one
  # wildcard level only, so a three-level host has no edge certificate on the
  # Free plan and fails the handshake before any of this matters. Hyphens are
  # free; Advanced Certificate Manager is not.
  hostname = "api-${var.environment}-frubble.${var.domain}"
}

module "tunnel" {
  source = "../../../modules/cloudflare/tunnel"

  account_id = var.account_id
  name       = "frubble-${var.environment}"
  hostname   = local.hostname
  app_port   = var.app_port
}

module "dns" {
  source = "../../../modules/cloudflare/dns-record"

  zone_id  = var.zone_id
  hostname = local.hostname
  target   = module.tunnel.cname_target
  comment  = "frubble ${var.environment} — managed by terraform"
}

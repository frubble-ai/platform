locals {
  # One level under the apex (api-stg.<domain>): Universal SSL covers the apex
  # and one wildcard level only, so api.stg.<domain> would need Advanced
  # Certificate Manager.
  hostname = "api-${var.environment}.${var.domain}"
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

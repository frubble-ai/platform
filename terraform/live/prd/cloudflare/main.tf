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

# Proves control of the API's hostname to Certificate Manager, which issues
# the load balancer's certificate against it before the hostname itself moves.
# Permanent: renewals reuse it. Values come from the GCP root's
# certificate_dns_authorization output, through repository variables, and the
# record exists only once they are set.
module "certificate_authorization" {
  source = "../../../modules/cloudflare/dns-record"
  count  = var.certificate_dns_authorization_name == "" ? 0 : 1

  zone_id  = var.zone_id
  hostname = trimsuffix(var.certificate_dns_authorization_name, ".")
  type     = "CNAME"
  target   = trimsuffix(var.certificate_dns_authorization_target, ".")
  proxied  = false
  comment  = "frubble ${var.environment} certificate authorization — managed by terraform"
}

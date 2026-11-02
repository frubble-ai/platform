# ---------- the web app's hostname ----------
# The same load balancer as the API, DNS-only for the same reason, and its own
# certificate authorization. The authorization exists once the GCP root's
# handoff has the app's record; the A record once the handoff lists the app
# as published, so the hostname never points at a load balancer that cannot
# serve TLS for it yet. The certificate issues against the authorization, so
# a new host's A record follows on the next run after (docs/crossing-roots.md).
locals {
  app_authorization = local.gcp == null ? null : try(local.gcp.certificate_dns_authorizations.app, null)
}

module "app" {
  source = "../../../modules/cloudflare/dns-record"
  count  = contains(local.published_hosts, "app") ? 1 : 0

  zone_id  = var.zone_id
  hostname = module.shared.app_hostname
  type     = "A"
  target   = local.gcp.load_balancer_ip
  proxied  = false
  comment  = "frubble ${module.shared.environment} app — managed by terraform"
}

module "app_certificate_authorization" {
  source = "../../../modules/cloudflare/dns-record"
  count  = local.app_authorization == null ? 0 : 1

  zone_id  = var.zone_id
  hostname = trimsuffix(local.app_authorization.name, ".")
  type     = "CNAME"
  target   = trimsuffix(local.app_authorization.data, ".")
  proxied  = false
  comment  = "frubble ${module.shared.environment} app certificate authorization — managed by terraform"
}

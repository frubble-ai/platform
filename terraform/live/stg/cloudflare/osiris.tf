# ---------- osiris's hostname ----------
# The same load balancer as the API, DNS-only for the same reason, and its own
# certificate authorization. The authorization exists once the GCP root's
# handoff has osiris's record; the A record once the handoff lists osiris
# as published, so the hostname never points at a load balancer that cannot
# serve TLS for it yet. The certificate issues against the authorization, so
# a new host's A record follows on the next run after (docs/crossing-roots.md).
locals {
  osiris_authorization = local.gcp == null ? null : try(local.gcp.certificate_dns_authorizations.osiris, null)
}

module "osiris" {
  source = "../../../modules/cloudflare/dns-record"

  zone_id  = var.zone_id
  hostname = module.shared.osiris_hostname
  type     = "A"
  target   = local.gcp.load_balancer_ip
  proxied  = false
  comment  = "frubble ${module.shared.environment} osiris — managed by terraform"

  lifecycle {
    enabled = var.enabled && contains(local.published_hosts, "osiris")
  }
}

module "osiris_certificate_authorization" {
  source = "../../../modules/cloudflare/dns-record"

  zone_id  = var.zone_id
  hostname = trimsuffix(local.osiris_authorization.name, ".")
  type     = "CNAME"
  target   = trimsuffix(local.osiris_authorization.data, ".")
  proxied  = false
  comment  = "frubble ${module.shared.environment} osiris certificate authorization — managed by terraform"

  lifecycle {
    enabled = local.osiris_authorization != null
  }
}

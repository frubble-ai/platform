# The environment's shared values: its name, zone and hostnames (README,
# "Shared values").
module "shared" {
  source = "../shared"
}

locals {
  hostname = module.shared.api_hostname
  # The hostnames whose A record this root publishes, from the GCP root's handoff:
  # each joins once it serves TLS and stays. A handoff written before the
  # list existed carries none, and the API's record was live by then.
  published_hosts = local.gcp == null ? [] : try(local.gcp.published_hosts, ["api"])
}

# The API's public name, straight to the load balancer and DNS-only, so Cloud
# Armor's per-IP limit sees each client's own address. Exists once the GCP
# root's handoff lists it as published (handoff.tf).
module "api" {
  source = "../../../modules/cloudflare/dns-record"
  count  = contains(local.published_hosts, "api") ? 1 : 0

  zone_id  = var.zone_id
  hostname = local.hostname
  type     = "A"
  target   = local.gcp.load_balancer_ip
  proxied  = false
  comment  = "frubble ${module.shared.environment} api — managed by terraform"
}

# Proves control of the API's hostname to Certificate Manager, which issues
# the load balancer's certificate against it before the hostname itself moves.
# Permanent: renewals reuse it. From the same handoff as the address above,
# so the two never arrive apart.
module "certificate_authorization" {
  source = "../../../modules/cloudflare/dns-record"
  count  = local.gcp == null ? 0 : 1

  zone_id  = var.zone_id
  hostname = trimsuffix(local.gcp.certificate_dns_authorization.name, ".")
  type     = "CNAME"
  target   = trimsuffix(local.gcp.certificate_dns_authorization.data, ".")
  proxied  = false
  comment  = "frubble ${module.shared.environment} certificate authorization — managed by terraform"
}


# ---------- the web app's hostname ----------
# The same load balancer as the API, DNS-only for the same reason, and its own
# certificate authorization. The authorization exists once the GCP root's
# handoff has the app's record; the A record once the handoff lists the app
# as published, so the hostname never points at a load balancer that cannot
# serve TLS for it yet. The certificate issues against the authorization, so
# a new host's A record follows on the next run after (README, "Crossing
# roots").
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

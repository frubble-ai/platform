# The environment's shared values: its name, zone and hostnames (README,
# "Shared values").
module "shared" {
  source = "../shared"
}

locals {
  hostname = module.shared.api_hostname
}

# The API's public name, straight to the load balancer and DNS-only, so Cloud
# Armor's per-IP limit sees each client's own address. Exists once the GCP
# root has written its handoff (handoff.tf).
module "api" {
  source = "../../../modules/cloudflare/dns-record"
  count  = local.gcp == null ? 0 : 1

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


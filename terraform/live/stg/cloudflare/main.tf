# The environment's shared values: its name, zone and hostnames (README,
# "Shared values").
module "shared" {
  source = "../shared"
}

locals {
  hostname = module.shared.api_hostname
}

# The API's public name, straight to the load balancer and DNS-only, so Cloud
# Armor's per-IP limit sees each client's own address. Created once the GCP
# root's load_balancer_ip output is in the repository variable.
module "api" {
  source = "../../../modules/cloudflare/dns-record"
  count  = var.origin_ip == "" ? 0 : 1

  zone_id  = var.zone_id
  hostname = local.hostname
  type     = "A"
  target   = var.origin_ip
  proxied  = false
  comment  = "frubble ${module.shared.environment} api — managed by terraform"
}

# Proves control of the API's hostname to Certificate Manager, which issues
# the load balancer's certificate against it before the hostname itself moves.
# Permanent: renewals reuse it. Values come from the GCP root's
# certificate_dns_authorization output, through repository variables. The
# record exists once both are set; one without the other fails the plan
# (variables.tf), so a missing variable can never read as "delete it".
module "certificate_authorization" {
  source = "../../../modules/cloudflare/dns-record"
  count  = var.certificate_dns_authorization_name != "" && var.certificate_dns_authorization_target != "" ? 1 : 0

  zone_id  = var.zone_id
  hostname = trimsuffix(var.certificate_dns_authorization_name, ".")
  type     = "CNAME"
  target   = trimsuffix(var.certificate_dns_authorization_target, ".")
  proxied  = false
  comment  = "frubble ${module.shared.environment} certificate authorization — managed by terraform"
}


# What the Cloudflare root needs from here, as one object under that root's
# prefix in the management bucket (README, "Crossing roots"): the address the
# hostnames resolve to and, per hostname, the CNAME that proves it to
# Certificate Manager. One object, so the Cloudflare root never sees one
# value without the other. `certificate_dns_authorization` is the API's, from
# before there was a record per host; the Cloudflare root reads the map.
# `published_hosts` names the hostnames whose A record the Cloudflare root
# publishes, pointing them here. Each joins once it serves TLS, and stays, so
# a renewal that shows its certificate as provisioning again never takes its
# A record down. It is the previous handoff's list, without hosts the load
# balancer no longer has, plus the hosts serving now.
locals {
  handoff_name = "${module.shared.environment}/cloudflare/handoff/gcp.json"
  hosts        = keys(module.load_balancer.dns_authorization_records)
}

data "google_storage_bucket_objects" "previous_handoff" {
  bucket     = var.management_state_bucket
  match_glob = local.handoff_name
}

data "google_storage_bucket_object_content" "previous_handoff" {
  count = length(data.google_storage_bucket_objects.previous_handoff.bucket_objects) > 0 ? 1 : 0

  bucket = var.management_state_bucket
  name   = local.handoff_name
}

locals {
  previously_published = try(
    jsondecode(data.google_storage_bucket_object_content.previous_handoff[0].content).published_hosts,
    [],
  )
  published_hosts = sort(distinct(concat(
    [for host in local.previously_published : host if contains(local.hosts, host)],
    module.load_balancer.serving_hosts,
  )))
}

resource "google_storage_bucket_object" "cloudflare_handoff" {
  bucket       = var.management_state_bucket
  name         = local.handoff_name
  content_type = "application/json"
  content = jsonencode({
    load_balancer_ip               = module.load_balancer.ip_address
    certificate_dns_authorization  = module.load_balancer.dns_authorization_records["api"]
    certificate_dns_authorizations = module.load_balancer.dns_authorization_records
    published_hosts                = local.published_hosts
  })
}

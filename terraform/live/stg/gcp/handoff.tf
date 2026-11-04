# What the Cloudflare root needs from here, as one object under that root's
# prefix in the management bucket (docs/crossing-roots.md): the address the
# hostnames resolve to and, per hostname, the CNAME that proves it to
# Certificate Manager. One object, so the Cloudflare root never sees one
# value without the other. `certificate_dns_authorization` is the API's, from
# before there was a record per host; the Cloudflare root reads the map.
# `published_hosts` names the hostnames whose A record the Cloudflare root
# publishes, pointing them here. Each joins once it serves TLS, and stays, so
# a renewal that shows its certificate as provisioning again never takes its
# A record down. It is the previous handoff's list, without hosts the load
# balancer no longer has, plus the hosts serving now.
#
# The object is named by its content (`gcp-<hash>.json`), and the new one is
# written before the old one is deleted: there is always a handoff, and a
# changed content is always a new object, never an update the provider cannot
# plan.
locals {
  handoff_prefix = "${module.shared.environment}/cloudflare/handoff/"
  # Nothing while stg is switched off: the object below is deleted with the
  # load balancer, and the Cloudflare root, finding no handoff, drops the
  # records that pointed at it.
  hosts = var.enabled ? keys(module.load_balancer.dns_authorization_records) : []
}

data "google_storage_bucket_objects" "previous_handoff" {
  bucket = var.management_state_bucket
  prefix = "${local.handoff_prefix}gcp"
}

# Every earlier GCP handoff there: one normally, two after an apply that wrote
# the new one and failed before deleting the old, `gcp.json` from before the
# objects were named by content.
data "google_storage_bucket_object_content" "previous_handoff" {
  for_each = toset([
    for object in data.google_storage_bucket_objects.previous_handoff.bucket_objects : object.name
    if can(regex("^${local.handoff_prefix}gcp(-[0-9a-f]{16})?\\.json$", object.name))
  ])

  bucket = var.management_state_bucket
  name   = each.value
}

locals {
  # A handoff written before the list existed published the API's record
  previously_published = flatten([
    for object in data.google_storage_bucket_object_content.previous_handoff :
    try(jsondecode(object.content).published_hosts, ["api"])
  ])
  published_hosts = sort(distinct(concat(
    [for host in local.previously_published : host if contains(local.hosts, host)],
    var.enabled ? module.load_balancer.serving_hosts : [],
  )))

  handoff_content = !var.enabled ? null : jsonencode({
    load_balancer_ip               = module.load_balancer.ip_address
    certificate_dns_authorization  = module.load_balancer.dns_authorization_records["api"]
    certificate_dns_authorizations = module.load_balancer.dns_authorization_records
    published_hosts                = local.published_hosts
  })
}

resource "google_storage_bucket_object" "cloudflare_handoff" {
  bucket       = var.management_state_bucket
  name         = "${local.handoff_prefix}gcp-${substr(sha256(local.handoff_content), 0, 16)}.json"
  content_type = "application/json"
  content      = local.handoff_content

  lifecycle {
    create_before_destroy = true
    enabled               = var.enabled
  }
}

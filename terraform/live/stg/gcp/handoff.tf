# What the Cloudflare root needs from here, as one object under that root's
# prefix in the management bucket (README, "Crossing roots"): the address the
# API hostname resolves to and the CNAME that proves the hostname to
# Certificate Manager. One object, so the Cloudflare root never sees one
# value without the other.
resource "google_storage_bucket_object" "cloudflare_handoff" {
  bucket       = var.management_state_bucket
  name         = "${module.shared.environment}/cloudflare/handoff/gcp.json"
  content_type = "application/json"
  content = jsonencode({
    load_balancer_ip              = module.load_balancer.ip_address
    certificate_dns_authorization = module.load_balancer.dns_authorization_records["api"]
  })
}

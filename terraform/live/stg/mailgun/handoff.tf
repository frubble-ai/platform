# What the Cloudflare root needs from here, as one object under that root's
# prefix in the management bucket (README, "Crossing roots"): the DKIM record,
# the one record only Mailgun can give.
resource "google_storage_bucket_object" "cloudflare_handoff" {
  bucket       = var.management_state_bucket
  name         = "${module.shared.environment}/cloudflare/handoff/mailgun.json"
  content_type = "application/json"
  content = jsonencode({
    dkim_record = {
      name  = local.dkim_name
      value = local.dkim_value
    }
  })
}

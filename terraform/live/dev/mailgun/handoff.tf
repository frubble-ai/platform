# What the Cloudflare root needs from here, as one object under that root's
# prefix in the management bucket (docs/crossing-roots.md): the DKIM record,
# the one record only Mailgun can give. The object is named by its content
# (`mailgun-<hash>.json`), and the new one is written before the old one is
# deleted: there is always a handoff, and a changed content is always a new
# object, never an update the provider cannot plan.
locals {
  handoff_content = jsonencode({
    dkim_record = {
      name  = local.dkim_name
      value = local.dkim_value
    }
  })
}

resource "google_storage_bucket_object" "cloudflare_handoff" {
  bucket       = var.management_state_bucket
  name         = "${module.shared.environment}/cloudflare/handoff/mailgun-${substr(sha256(local.handoff_content), 0, 16)}.json"
  content_type = "application/json"
  content      = local.handoff_content

  lifecycle {
    create_before_destroy = true
  }
}

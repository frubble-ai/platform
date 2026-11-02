# The environment's shared values: its name, zone and hostnames (README,
# "Shared values").
module "shared" {
  source = "../shared"
}

# The sending domain. Mail from the prd worker leaves as noreply@ it; the
# records that let receivers trust that mail are published by the Cloudflare
# root, from the handoff object this root writes (handoff.tf).
resource "mailgun_domain" "sending" {
  name          = module.shared.sending_domain
  region        = "us"
  dkim_key_size = 2048
  # Fixed, so the DKIM record's name is known before the domain exists.
  dkim_selector = local.dkim_selector
  # Its own key: without this Mailgun lets a subdomain sign with a parent
  # domain's key when that parent is registered too, and the record below
  # would never appear.
  force_dkim_authority = true
  spam_action          = "disabled"
  wildcard             = false
  # Transactional codes only: no links rewritten, no pixels.
  click_tracking = false
  open_tracking  = false
  web_scheme     = "https"
}

locals {
  dkim_selector = "mg"
  dkim_name     = "${local.dkim_selector}._domainkey.${module.shared.sending_domain}"
  dkim_value = one([
    for record in mailgun_domain.sending.sending_records_set : record.value
    if record.record_type == "TXT" && record.name == local.dkim_name
  ])
}

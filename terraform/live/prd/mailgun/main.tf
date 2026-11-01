# The sending domain. Mail from the prd worker leaves as noreply@ it; the
# records that let receivers trust that mail are published by the Cloudflare
# root, from the outputs here (README, "Email").
resource "mailgun_domain" "sending" {
  name          = var.sending_domain
  region        = "us"
  dkim_key_size = 2048
  # Fixed, so the DKIM record's name is known before the domain exists.
  dkim_selector = local.dkim_selector
  spam_action   = "disabled"
  wildcard      = false
  # Transactional codes only: no links rewritten, no pixels.
  click_tracking = false
  open_tracking  = false
  web_scheme     = "https"
}

locals {
  dkim_selector = "mg"
  dkim_name     = "${local.dkim_selector}._domainkey.${var.sending_domain}"
}

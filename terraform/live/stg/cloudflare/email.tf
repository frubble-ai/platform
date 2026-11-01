# ---------- the sending domain ----------
# Registered at the email provider here, beside the records it needs, because
# a sending domain is DNS configuration: the provider hands back the DKIM key
# and nothing else that any other root would read.
locals {
  sending_domain = "stg.${var.domain}"
  dkim_selector  = "mg"
}

resource "mailgun_domain" "sending" {
  name          = local.sending_domain
  region        = "us"
  dkim_key_size = 2048
  # Fixed, so the DKIM record's name is known at plan time and the record
  # below can exist before the domain does.
  dkim_selector = local.dkim_selector
  spam_action   = "disabled"
  wildcard      = false
  # Transactional codes only: no links rewritten, no pixels.
  click_tracking = false
  open_tracking  = false
  web_scheme     = "https"
}

# What the provider asks for to sign and authorize our mail. DNS-only, like
# every record in this root.
module "email_spf" {
  source = "../../../modules/cloudflare/dns-record"

  zone_id  = var.zone_id
  hostname = local.sending_domain
  type     = "TXT"
  target   = "v=spf1 include:mailgun.org ~all"
  proxied  = false
  comment  = "frubble stg email SPF — managed by terraform"
}

module "email_dkim" {
  source = "../../../modules/cloudflare/dns-record"

  zone_id  = var.zone_id
  hostname = "${local.dkim_selector}._domainkey.${local.sending_domain}"
  type     = "TXT"
  target = one([
    for record in mailgun_domain.sending.sending_records_set : record.value
    if record.record_type == "TXT" && record.name == "${local.dkim_selector}._domainkey.${local.sending_domain}"
  ])
  proxied = false
  comment = "frubble stg email DKIM — managed by terraform"
}

# Report-only, so a receiver that fails SPF or DKIM on our mail still delivers
# it while the records settle.
module "email_dmarc" {
  source = "../../../modules/cloudflare/dns-record"

  zone_id  = var.zone_id
  hostname = "_dmarc.${local.sending_domain}"
  type     = "TXT"
  target   = "v=DMARC1; p=none"
  proxied  = false
  comment  = "frubble stg email DMARC — managed by terraform"
}

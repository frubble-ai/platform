# ---------- the sending domain's records ----------
# The domain itself is registered at Mailgun by the prd/mailgun root; what
# receivers check lives here, DNS-only like every record in this root. SPF and
# DMARC are fixed text. DKIM is the one record only Mailgun can give: it
# crosses from that root's outputs as repository variables, the way the
# certificate authorization does, and exists once both are set.
locals {
  sending_domain = var.domain
}

module "email_spf" {
  source = "../../../modules/cloudflare/dns-record"

  zone_id  = var.zone_id
  hostname = local.sending_domain
  type     = "TXT"
  target   = "v=spf1 include:mailgun.org ~all"
  proxied  = false
  comment  = "frubble prd email SPF — managed by terraform"
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
  comment  = "frubble prd email DMARC — managed by terraform"
}

module "email_dkim" {
  source = "../../../modules/cloudflare/dns-record"
  count  = var.mailgun_dkim_name != "" && var.mailgun_dkim_value != "" ? 1 : 0

  zone_id  = var.zone_id
  hostname = trimsuffix(var.mailgun_dkim_name, ".")
  type     = "TXT"
  target   = var.mailgun_dkim_value
  proxied  = false
  comment  = "frubble prd email DKIM — managed by terraform"
}

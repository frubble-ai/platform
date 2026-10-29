# Zone-wide security posture. These affect stg and prd at once, which is why
# they live in a reviewed root rather than in _setup: lowering min TLS or
# taking SSL off strict should require a plan a reviewer reads and an approval,
# not a hand-apply by whoever holds the bootstrap credential.
#
# strict, not full: `full` accepts any certificate at the origin including a
# self-signed one, so the edge-to-origin leg can be intercepted without
# anything failing visibly.
#
# The first plan after this moves shows all seven as additions. That is not a
# change at the edge — these settings always exist on a zone, and "create" here
# writes the value that is already there. The destroy side is the dangerous
# one, which is why _setup forgets them with `removed` instead of deleting.
resource "cloudflare_zone_setting" "this" {
  for_each = var.zone_settings

  zone_id    = var.zone_id
  setting_id = each.key
  value      = each.value
}

resource "cloudflare_dns_record" "org" {
  for_each = var.records

  zone_id = var.zone_id
  name    = each.key
  type    = each.value.type
  content = each.value.content
  proxied = each.value.proxied
  comment = each.value.comment

  # Cloudflare rejects an explicit TTL on a proxied record; 1 means automatic
  # and is the only value accepted there.
  ttl = each.value.proxied ? 1 : each.value.ttl
}

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

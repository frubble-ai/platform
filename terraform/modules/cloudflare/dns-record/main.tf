# One record. Proxied is the right default for a tunnel target, where the edge
# holds the certificate and the DDoS protection; a record that must resolve
# to the real address (a load balancer the per-IP rate limit sits on, a
# certificate authorization) is published DNS-only instead.
resource "cloudflare_dns_record" "this" {
  zone_id = var.zone_id
  name    = var.hostname
  type    = var.type
  content = var.target
  proxied = var.proxied
  comment = var.comment

  # Cloudflare rejects an explicit TTL on a proxied record; 1 means automatic
  # and is the only value accepted there.
  ttl = var.proxied ? 1 : var.ttl
}

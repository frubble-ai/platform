# Proxied, always. Unproxied would publish the tunnel target directly and skip
# the edge, which is where the certificate and the DDoS protection live.
resource "cloudflare_dns_record" "this" {
  zone_id = var.zone_id
  name    = var.hostname
  type    = "CNAME"
  content = var.target
  proxied = true
  comment = var.comment

  # 1 means "automatic", which is the only value Cloudflare accepts on a
  # proxied record — the edge controls the real TTL.
  ttl = 1
}

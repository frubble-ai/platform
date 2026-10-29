# The connector dials out to Cloudflare and holds the connection open, so the
# origin needs no inbound rule, no reserved address and no open port.

# `tunnel_secret` is deliberately not set. Supplying one would mean Terraform
# generated it, and anything Terraform generates is written to state in clear
# text — which is precisely what the standard forbids for the tunnel token.
# Letting Cloudflare mint the secret keeps it out of state entirely; the
# deploy workflow fetches the token from the API at run time and writes it to
# Secret Manager under its own identity.
resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.account_id
  name       = var.name
  config_src = "cloudflare"
}

# Ingress rules are evaluated top-down and the catch-all must stay last; a
# rule added after it is unreachable and silently does nothing.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = [
      {
        hostname = var.hostname
        service  = "http://127.0.0.1:${var.app_port}"
        origin_request = {
          connect_timeout   = 10
          no_happy_eyeballs = false
        }
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

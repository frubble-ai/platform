output "id" {
  description = "Tunnel id. The deploy workflow uses it to fetch the token from the Cloudflare API; the token itself never passes through Terraform."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "cname_target" {
  description = "Target for the proxied CNAME that publishes the hostname."
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
}

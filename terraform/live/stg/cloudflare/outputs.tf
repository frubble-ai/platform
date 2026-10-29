output "hostname" {
  value = local.hostname
}

output "tunnel_id" {
  description = "Read by the deploy job to fetch the token from the Cloudflare API."
  value       = module.tunnel.id
}

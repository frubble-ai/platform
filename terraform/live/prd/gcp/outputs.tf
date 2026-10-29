output "instance_name" {
  value = module.api.instance_name
}

output "app_port" {
  description = "The port the tunnel's ingress rule must point at. Passed to the Cloudflare root as a variable, not read from this state — which is why that root needs no access to this bucket."
  value       = var.app_port
}

output "tunnel_token_secret_id" {
  description = "Secret the deploy job writes the token into."
  value       = module.tunnel_token.secret_id
}

output "registry_url" {
  value = module.registry.url
}

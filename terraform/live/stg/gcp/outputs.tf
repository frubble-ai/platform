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

output "load_balancer_ip" {
  description = "Address api_hostname must resolve to. Copied into the repository variable the Cloudflare root reads."
  value       = module.load_balancer.ip_address
}

output "certificate_dns_authorization" {
  description = "CNAME that proves control of api_hostname to Certificate Manager. Published before the hostname itself, and kept: renewals reuse it."
  value       = module.load_balancer.dns_authorization_records["api"]
}

output "api_service_name" {
  value = module.api_service.name
}

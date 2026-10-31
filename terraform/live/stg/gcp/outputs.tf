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

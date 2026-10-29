output "hostname" {
  description = "The published hostname."
  value       = cloudflare_dns_record.this.name
}

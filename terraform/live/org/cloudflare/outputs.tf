output "record_names" {
  value = keys(cloudflare_dns_record.org)
}

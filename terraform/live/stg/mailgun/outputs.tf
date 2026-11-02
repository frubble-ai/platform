output "sending_domain" {
  value = mailgun_domain.sending.name
}

# What the Cloudflare root publishes for this domain, read from the handoff
# object (handoff.tf); here too, for a person.
output "dkim_record_name" {
  value = local.dkim_name
}

output "dkim_record_value" {
  value = local.dkim_value
}

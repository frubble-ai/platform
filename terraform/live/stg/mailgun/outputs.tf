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

# Not secret: an id is what an audit log entry names, and a version name is
# what the worker's secret binding resolves `latest` to.
output "sending_key_ids" {
  value = { for generation, key in mailgun_api_key.sending : generation => key.id }
}

output "sending_key_secret_version" {
  value = google_secret_manager_secret_version.sending_key.name
}

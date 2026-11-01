output "sending_domain" {
  value = mailgun_domain.sending.name
}

# What the Cloudflare root publishes for this domain: the one record only
# Mailgun can give. Crosses roots as repository variables, like the
# certificate authorization (README, "Email").
output "dkim_record_name" {
  value = local.dkim_name
}

output "dkim_record_value" {
  value = one([
    for record in mailgun_domain.sending.sending_records_set : record.value
    if record.record_type == "TXT" && record.name == local.dkim_name
  ])
}

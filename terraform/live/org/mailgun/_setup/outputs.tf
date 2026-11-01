# The values, so they can be read once and piped where they go:
#
#   terraform output -raw apply_key | gh secret set MAILGUN_APPLY_API_KEY --env stg
#   terraform output -json sending_keys | jq -r .stg \
#     | gcloud secrets versions add frubble_stg_email_api-key --project frubble-stg --data-file=-
#
# Marked sensitive, which keeps them out of the logs, not out of the state.
# The state is what protects them: CMEK-encrypted, in the management bucket,
# under a prefix no CI identity can read.
output "apply_key" {
  description = "Admin key for apply jobs. Goes into the MAILGUN_APPLY_API_KEY secret of each environment that applies a mailgun root."
  value       = mailgun_api_key.apply.secret
  sensitive   = true
}

output "sending_keys" {
  description = "Per environment handle, the domain sending key for its worker. Goes into the environment's email/api-key secret."
  value       = { for env, key in mailgun_api_key.sending : env => key.secret }
  sensitive   = true
}

# Not secret: an id is what an audit log entry names.
output "key_ids" {
  value = merge(
    { apply = mailgun_api_key.apply.id },
    { for env, key in mailgun_api_key.sending : "sending-${env}" => key.id },
  )
}

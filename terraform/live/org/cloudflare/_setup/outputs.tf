output "zone_id" {
  value = var.zone_id
}

# The values, so they can be read once and piped into GitHub:
#
#   terraform output -raw plan_token | gh secret set CLOUDFLARE_PLAN_TOKEN
#
# Marked sensitive, which keeps them out of the plan and apply logs. It does
# not keep them out of the state file — `sensitive` masks output, it does not
# encrypt storage. The state is what protects them: CMEK-encrypted, in the
# management bucket, under a prefix no CI identity can read.
output "plan_token" {
  description = "Read-only token for plan jobs. Goes into the CLOUDFLARE_PLAN_TOKEN repository secret."
  value       = cloudflare_account_token.plan.value
  sensitive   = true
}

# Not secret, and worth having: an id is what an audit log entry names, so
# these are how you tell which token did something.
output "plan_token_id" {
  value = cloudflare_account_token.plan.id
}

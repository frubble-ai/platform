output "state_bucket" {
  description = "Bucket holding this environment's workload state. Passed to init with -backend-config."
  value       = module.state.name
}

output "state_key" {
  value = module.state.kms_key_id
}

output "secrets_key" {
  description = "Key encrypting this environment's secrets. Separate from the state key on purpose."
  value       = google_kms_crypto_key.secrets.id
}

output "plan_spoke" {
  value = module.plan_spoke.email
}

output "apply_spoke" {
  value = module.apply_spoke.email
}

output "tunnel_token_writer" {
  description = "Identity the deploy job uses to write the tunnel token. The workload root grants it access to that one secret."
  value       = module.tunnel_token_writer.email
}

output "deploy_spoke" {
  description = "Identity frubble-app deploys as. Empty outside stg."
  value       = one(module.deploy_spoke[*].email)
}

output "instance_service_account" {
  description = "Identity the VM runs as. Created here so the apply spoke never needs serviceAccountAdmin."
  value       = google_service_account.instance.email
}

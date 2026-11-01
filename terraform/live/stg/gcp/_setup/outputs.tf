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

output "deploy_spoke" {
  description = "Identity frubble-app deploys as. Empty outside stg."
  value       = one(module.deploy_spoke[*].email)
}

output "api_service_account" {
  description = "Identity the API's Cloud Run service runs as. Created here so the apply spoke never needs serviceAccountAdmin."
  value       = google_service_account.api.email
}

output "worker_service_account" {
  description = "Identity the email worker's Cloud Run service runs as."
  value       = google_service_account.worker.email
}

output "push_service_account" {
  description = "Identity Pub/Sub pushes to the worker as."
  value       = google_service_account.push.email
}

# Passed through from org for the workload root, which can read this state and
# not the org one. The value crosses two roots by reference, never by hand.
output "workload_identity_pool" {
  value = local.org.workload_identity_pool
}

output "repositories" {
  value = local.org.repositories
}

output "backend_deploy_hub_name" {
  description = "Full resource name of the backend deploy hub. Null outside stg."
  value       = var.environment == "stg" ? local.org.backend_deploy_hub_name : null
}

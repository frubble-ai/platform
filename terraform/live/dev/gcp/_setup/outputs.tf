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
  description = "Identity frubble-app deploys as. Empty where the application does not deploy."
  value       = one(module.deploy_spoke[*].email)
}

output "api_service_account" {
  description = "Identity the API's Cloud Run service runs as. Created here so the apply spoke never needs serviceAccountAdmin."
  value       = google_service_account.api.email
}

output "app_service_account" {
  description = "Identity the web app's Cloud Run service runs as."
  value       = google_service_account.app.email
}

output "worker_service_account" {
  description = "Identity the email worker's Cloud Run service runs as."
  value       = google_service_account.worker.email
}

output "push_service_account" {
  description = "Identity Pub/Sub pushes to the worker as."
  value       = google_service_account.push.email
}

output "osiris_service_account" {
  description = "Identity the osiris API service and migration job run as."
  value       = google_service_account.osiris.email
}

output "osiris_worker_service_account" {
  description = "Identity the osiris worker service runs as."
  value       = google_service_account.osiris_worker.email
}

output "osiris_tasks_service_account" {
  description = "Identity Cloud Tasks calls the osiris worker as."
  value       = google_service_account.osiris_tasks.email
}

output "database_grants_service_account" {
  description = "Identity the database grant job runs as."
  value       = google_service_account.database_grants.email
}

output "osiris_deploy_spoke" {
  description = "Identity osiris deploys as."
  value       = module.osiris_deploy_spoke.email
}

output "osiris_deploy_hub_name" {
  description = "Full resource name of this environment's osiris deploy hub."
  value       = local.org.osiris_deploy_hub_names[var.environment]
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
  description = "Full resource name of this environment's deploy hub. Null where the application does not deploy."
  value       = local.app_deploys ? local.org.backend_deploy_hub_names[var.environment] : null
}

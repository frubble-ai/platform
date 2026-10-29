# Every other root reads these through terraform_remote_state. Values are
# never copied between roots by hand: a stale copy of an identity name fails
# as a permission error at apply time, which is the hardest kind to diagnose.

output "management_project_id" {
  value = var.management_project_id
}

output "management_state_bucket" {
  description = "Bucket for org, _setup and Cloudflare state. Passed to init with -backend-config."
  value       = module.management_state.name
}

output "management_state_key" {
  value = module.management_state.kms_key_id
}

output "environment_projects" {
  description = "Project id per environment."
  value       = { for k, m in module.environment_project : k => m.project_id }
}

output "environment_project_numbers" {
  value = { for k, m in module.environment_project : k => m.number }
}

output "workload_identity_pool" {
  value = google_iam_workload_identity_pool.github.name
}

output "plan_provider" {
  description = "Full provider resource name the plan workflows pass to the auth action."
  value       = google_iam_workload_identity_pool_provider.plan.name
}

output "apply_provider" {
  value = google_iam_workload_identity_pool_provider.apply.name
}

output "audience" {
  description = "Audience the workflows must request. Pinning it stops a token minted for another Google resource from being replayed here."
  value       = local.audience
}

output "plan_hubs" {
  description = "Plan hub email per environment. The environment's plan spoke trusts exactly this."
  value       = { for k, m in module.plan_hub : k => m.email }
}

output "apply_hubs" {
  value = { for k, m in module.apply_hub : k => m.email }
}

output "tunnel_token_hubs" {
  description = "Tunnel-token hub per environment. Separate hubs: a shared one would let one environment's deploy write another's secret."
  value       = { for k, m in module.tunnel_token_hub : k => m.email }
}

output "backend_deploy_hub" {
  value = module.backend_deploy_hub.email
}

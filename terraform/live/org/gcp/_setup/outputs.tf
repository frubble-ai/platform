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
  value       = { for k, sa in google_service_account.tunnel_token_hub : k => sa.email }
}

output "tunnel_token_hub_names" {
  description = "Full resource name per environment, for the roots that bind trust on them."
  value       = { for k, sa in google_service_account.tunnel_token_hub : k => sa.name }
}

output "backend_deploy_hub" {
  value = google_service_account.backend_deploy_hub.email
}

output "backend_deploy_hub_name" {
  value = google_service_account.backend_deploy_hub.name
}

output "hub_trust_editor_role" {
  description = "Role an environment's apply spoke holds on its own hubs, and on nothing else."
  value       = google_project_iam_custom_role.hub_trust_editor.id
}

output "repositories" {
  description = "owner/name of both repositories, as the trust entries spell them."
  value = {
    platform = local.platform_repo
    backend  = local.backend_repo
  }
}

output "plan_store_bucket" {
  description = "Private bucket for full plan and apply output. Set as the PLAN_STORE_BUCKET repository variable."
  value       = module.plan_store.name
}

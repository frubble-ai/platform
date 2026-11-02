# The domain must exist at Mailgun before a key can be scoped to it, so the
# environment's mailgun root applies first (docs/getting-started.md).
resource "mailgun_api_key" "sending" {
  for_each = local.sending_keys

  role        = "sending"
  kind        = "domain"
  domain_name = each.value.domain
  description = "frubble ${each.value.environment} worker, generation ${each.value.generation}"
}

# Which key the secret holds. A key deleted in the dashboard leaves the state
# on refresh and is planned as a create, which `replace_triggered_by` on the
# key itself would not see; its id changing here is seen either way.
resource "terraform_data" "sending_key_identity" {
  for_each = local.sending_domains

  triggers_replace = [mailgun_api_key.sending["${each.key}-${local.current_generation}"].id]
}

# Into the secret the environment's GCP root created with a placeholder
# (its secrets.tf; the id joins the path with "_", as modules/gcp/secret
# explains). Through the write-only attribute: Secret Manager gets the value,
# this resource's state does not. The current generation's key; a new one
# replaces the version, the new one first, so a worker starting in between
# still finds `latest`.
resource "google_secret_manager_secret_version" "sending_key" {
  for_each = local.sending_domains

  secret                 = "projects/${var.environment_projects[each.key]}/secrets/frubble_${each.key}_email_api-key"
  secret_data_wo         = mailgun_api_key.sending["${each.key}-${local.current_generation}"].secret
  secret_data_wo_version = 1

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.sending_key_identity[each.key]]
  }
}

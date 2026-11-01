# The Mailgun keys the workers send with, created here rather than clicked in
# a dashboard, for the reason org/cloudflare/_setup gives: a key's role is the
# security boundary, and a role chosen in a dashboard is reviewed by nobody.
#
# Applied by setup-cd like the GCP _setup roots: as the bootstrap admin, in
# the `setup` environment, after a reviewer approves the run. The Mailgun
# credential is the account's admin key, the one made once in the dashboard,
# held by the `setup` and `stg` environments as MAILGUN_APPLY_API_KEY: Mailgun
# has no narrower role that creates domains or keys, so there is nothing for
# this root to mint for CI. What it mints is one sending key per domain, scoped
# to that domain, and it writes each straight into its environment's Secret
# Manager secret, so no key is ever printed or copied. The keys land in this
# root's state too, which lives under a prefix no CI identity can read
# (state_access.tf in org/gcp/_setup limits them to `<env>/mailgun/`).

# The domains, from each environment's shared values: the same name its
# mailgun root registers and its worker sends from (README, "Shared values").
# prd joins once prd/mailgun has applied.
module "stg_shared" {
  source = "../../../stg/shared"
}

locals {
  sending_domains = { stg = module.stg_shared.sending_domain }
}

# The domain must exist at Mailgun before a key can be scoped to it, so the
# environment's mailgun root applies first (README, Bootstrap).
resource "mailgun_api_key" "sending" {
  for_each = local.sending_domains

  role        = "sending"
  kind        = "domain"
  domain_name = each.value
  description = "frubble ${each.key} worker"
}

# Into the secret the environment's GCP root created with a placeholder
# (its secrets.tf; the id joins the path with "_", as modules/gcp/secret
# explains). Through the write-only attribute: Secret Manager gets the value,
# this resource's state does not. A new key, from a rotation in the dashboard
# or a `terraform apply -replace`, replaces the version, the new one first so
# a worker starting in between still finds `latest`.
resource "google_secret_manager_secret_version" "sending_key" {
  for_each = local.sending_domains

  secret                 = "projects/${var.environment_projects[each.key]}/secrets/frubble_${each.key}_email_api-key"
  secret_data_wo         = mailgun_api_key.sending[each.key].secret
  secret_data_wo_version = 1

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [mailgun_api_key.sending[each.key].id]
  }
}

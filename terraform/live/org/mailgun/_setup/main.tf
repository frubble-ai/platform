# The Mailgun keys the workers send with, created here rather than clicked in
# a dashboard, for the reason org/cloudflare/_setup gives: a key's role is the
# security boundary, and a role chosen in a dashboard is reviewed by nobody.
#
# Applied by mailgun-setup-cd like the GCP _setup roots by setup-cd: as the
# bootstrap admin, in the `setup` environment, after a reviewer approves. The Mailgun
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

  # The key generations alive at once. A worker instance reads its secret when
  # it starts and keeps that key until it stops, so a rotation is three pull
  # requests: add the next number (the secret moves to it, the old key stays
  # valid); roll the workers (the next deploy, or a redeploy from the app
  # repository's Actions); remove the old number. Deleting a key the dashboard
  # way skips the overlap: the apply then recreates it and the secret follows,
  # but sends fail until the workers roll.
  sending_key_generations = [1]
  current_generation      = max(local.sending_key_generations...)

  sending_keys = {
    for pair in setproduct(keys(local.sending_domains), local.sending_key_generations) :
    "${pair[0]}-${pair[1]}" => {
      environment = pair[0]
      domain      = local.sending_domains[pair[0]]
      generation  = pair[1]
    }
  }
}

# The domain must exist at Mailgun before a key can be scoped to it, so the
# environment's mailgun root applies first (README, Bootstrap).
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

# The worker's sending key, minted here: this environment's sending domain
# lives in a Mailgun account of its own (docs/email.md), and the only
# credential for that account is the admin key this root already applies with
# (the environment's MAILGUN_APPLY_API_KEY). org/mailgun/_setup holds the main
# account's admin key, which is prd's alone.
#
# dev/mailgun and stg/mailgun are the same files but for the backend prefix in
# versions.tf: change one, change the other.
#
# One key per generation, scoped to the domain this root registers, written
# straight into the secret the environment's GCP root created with a
# placeholder, so no key is ever printed or copied. The key lands in this
# root's state, under `<env>/mailgun/`, which only this environment's Mailgun
# apply identity and the bootstrap admin read (state_access.tf in
# org/gcp/_setup); that identity already holds the account's admin key, which
# can make any key, so the state reveals nothing it could not already get.
locals {
  # The key generations alive at once. A worker instance reads its secret when
  # it starts and keeps that key until it stops, so a rotation is three pull
  # requests: add the next number (the secret moves to it, the old key stays
  # valid); roll the worker (the next deploy, or a redeploy from the app
  # repository's Actions); remove the old number.
  sending_key_generations = [1]
  current_generation      = max(local.sending_key_generations...)

  # The secret's id, as modules/gcp/secret joins it.
  sending_key_secret = "projects/${var.project_id}/secrets/${join("_", ["frubble", module.shared.environment, "email", "api-key"])}"
}

# After the domain: a key can only be scoped to a domain that exists.
resource "mailgun_api_key" "sending" {
  for_each = toset([for g in local.sending_key_generations : tostring(g)])

  role        = "sending"
  kind        = "domain"
  domain_name = mailgun_domain.sending.name
  description = "frubble ${module.shared.environment} worker, generation ${each.key}"
}

# Which key the secret holds. A key deleted in the dashboard leaves the state
# on refresh and is planned as a create, which `replace_triggered_by` on the
# key itself would not see; its id changing here is seen either way.
resource "terraform_data" "sending_key_identity" {
  triggers_replace = [mailgun_api_key.sending[tostring(local.current_generation)].id]
}

# Through the write-only attribute: Secret Manager gets the value, this
# resource's state does not. The identity this root runs as may add and
# destroy versions of this one secret and read none (the grant is
# google_secret_manager_secret_iam_member.mailgun_writes_email_key in the GCP
# root's secrets.tf). A new key replaces the version, the new one first, so a
# worker starting in between still finds `latest`.
resource "google_secret_manager_secret_version" "sending_key" {
  secret                 = local.sending_key_secret
  secret_data_wo         = mailgun_api_key.sending[tostring(local.current_generation)].secret
  secret_data_wo_version = 1

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.sending_key_identity]
  }
}

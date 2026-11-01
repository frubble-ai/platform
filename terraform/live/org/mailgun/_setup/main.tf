# The long-lived Mailgun keys, created here rather than clicked in a
# dashboard, for the reason org/cloudflare/_setup gives: a key's role is the
# security boundary, and a role chosen in a dashboard is reviewed by nobody.
#
# This is the one Mailgun root that belongs in `_setup`: CI cannot run without
# these, and a person applies it holding a bootstrap admin key made once in
# the dashboard. Every value lands in this root's state, which lives in the
# management bucket under a prefix no CI identity can read (state_access.tf in
# org/gcp/_setup limits them to `<env>/mailgun/`); the README lists them as
# the secrets that reach state.

# ---------- the apply key ----------
# An environment secret, reached only by the apply job on merge. Creates and
# changes domains, so admin. There is no plan key: Mailgun has no read-only
# role, and a key a pull-request plan could reach would be one that writes
# (README, "Email").
resource "mailgun_api_key" "apply" {
  role        = "admin"
  kind        = "user"
  description = "frubble terraform apply"
}

# ---------- the sending keys ----------
# One per sending domain, scoped to it: the worker can send through that
# domain and do nothing else with the account. A domain is listed here once
# the environment's mailgun root has created it, so this root is applied
# again after that first apply (README, Bootstrap).
resource "mailgun_api_key" "sending" {
  for_each = var.sending_domains

  role        = "sending"
  kind        = "domain"
  domain_name = each.value
  description = "frubble ${each.key} worker"
}

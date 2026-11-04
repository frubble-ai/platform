# The Mailgun keys the workers send with, created here rather than clicked in
# a dashboard, for the reason org/cloudflare/_setup gives: a key's role is the
# security boundary, and a role chosen in a dashboard is reviewed by nobody.
#
# Applied by mailgun-setup-cd like the GCP _setup roots by setup-cd: as the
# bootstrap admin, in the `setup` environment, after a reviewer approves. The Mailgun
# credential is the account's admin key, the one made once in the dashboard,
# held by the `setup`, `stg` and `dev` environments as MAILGUN_APPLY_API_KEY: Mailgun
# has no narrower role that creates domains or keys, so there is nothing for
# this root to mint for CI. What it mints is one sending key per domain, scoped
# to that domain, and it writes each straight into its environment's Secret
# Manager secret, so no key is ever printed or copied. The keys land in this
# root's state too, which lives under a prefix no CI identity can read
# (state_access.tf in org/gcp/_setup limits them to `<env>/mailgun/`).

# The domains, from each environment's shared values: the same name its
# mailgun root registers and its worker sends from (docs/shared-values.md).
# Only the domains that exist: prd joins here once prd-cd has registered it
# (docs/getting-started.md), and until then the prd worker holds its placeholder.
module "stg_shared" {
  source = "../../../stg/shared"
}

# dev's own domain (dev.frubble.ai) and its own key, never stg's: the key is
# scoped to dev's domain and written into dev's project only.
module "dev_shared" {
  source = "../../../dev/shared"
}

locals {
  sending_domains = {
    stg = module.stg_shared.sending_domain
    dev = module.dev_shared.sending_domain
  }

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

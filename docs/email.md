# Email

Mail goes out through Mailgun, in the shape every provider here has. `stg/mailgun`,
`dev/mailgun` and `prd/mailgun` each register one sending domain, their own, their state in the management bucket under
`<env>/mailgun/`. `org/mailgun/_setup` mints one sending key per domain (role `sending`,
scoped to that domain, the worker's only credential) and writes it into the environment's
`email/api-key` secret through a write-only attribute, so no key is printed or copied and
the secret version's state holds none. The key does stay in the setup root's own state,
which no CI identity can read; it
runs in `mailgun-setup-cd` behind the same reviewer as the GCP `_setup` roots, after the
`stg-cd` run that registers the domain when one commit changes both. A worker instance reads
the secret when it starts and keeps that key until it stops, so a rotation keeps two keys
alive: add the next generation in the root (the secret moves to it), roll the workers, then
remove the old one; the root's comment spells the steps. Changing a sending domain ends the
same way: the worker that `stg-cd` rolls onto the new domain still holds the old domain's
key until it is rolled once more after `mailgun-setup-cd` has written the new one. The credential both
use is the account's admin key, made once in the Mailgun dashboard and held as
`MAILGUN_APPLY_API_KEY` by the `stg` and `setup` environments: Mailgun has no narrower role
that creates domains or keys, so there is nothing to mint for CI, unlike Cloudflare. There
is no `org/mailgun` live root: the account holds nothing shared that the provider manages.

dev is the exception to all of that: `dev.frubble.ai` lives in a Mailgun account of its
own (the main account's plan allows one custom domain, which is stg's), so nothing of dev's
is in the main account and `org/mailgun/_setup` never sees dev. dev's `MAILGUN_APPLY_API_KEY`
is that account's admin key, and `dev/mailgun` mints dev's sending key itself
(`sending_key.tf`, the same generations and the same write-only secret version as the setup
root) in the `dev-cd` run that registers the domain. Its federated identity may add and
destroy versions of `frubble_dev_email_api-key` and read none (`dev/gcp`'s `secrets.tf`).
The key is in `dev/mailgun`'s state, which only that identity and the bootstrap admin read,
and that identity already holds the account's admin key. dev-environment.md has the account.

The three roots are the exception to "planned on every pull request". Mailgun has no
read-only key: even its least role reads stored messages and logs, so a plan key would be a
credential reachable from an unreviewed branch, and the same identity could read the root's
state, where the provider records the domain's SMTP password and the sending keys. Instead
the apply on merge plans and applies in one job, as every apply does, and no identity
reachable from a pull request holds a Mailgun key or reads a mailgun state prefix. Nothing
uses SMTP; resetting that password in the dashboard kills the recorded one.

The sending domain comes from the environment's `shared/` (shared-values.md): the
mailgun root registers it, the Cloudflare root publishes its records, the GCP root hands it
to the worker, and none of the three spells it.

The records receivers check are the Cloudflare root's: SPF and DMARC are fixed text, and
DKIM, the one record only Mailgun can give, is the mailgun root's handoff to it (crossing-roots.md), published by the Cloudflare apply that follows the mailgun one in the same
run. `MAILGUN_ENABLED` turns the mailgun applies on once the admin key is in the
environments; until then they report nothing. The Mailgun provider records the
domain's SMTP password in state; nothing here uses SMTP, and resetting it in the dashboard
kills the recorded one.

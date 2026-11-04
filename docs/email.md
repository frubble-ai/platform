# Email

Mail goes out through Mailgun, in the shape every provider here has. `stg/mailgun`,
`dev/mailgun` and `prd/mailgun` each register one sending domain, their own, their state
in the management bucket under `<env>/mailgun/`. Each environment's worker sends with one
sending key (role `sending`, scoped to its domain, the worker's only credential), written
into the environment's `email/api-key` secret (`frubble_<env>_email_api-key`) through a
write-only attribute, so no key is printed or copied and the secret version's state holds
none.

## Accounts

| Account | Login (Bitwarden) | Plan | Domain | Who mints the sending key |
| ------- | ----------------- | ---- | ------ | ------------------------- |
| stg's own, `platform+mailgun-stg@frubble.ai` | `Mailgun - Frubble stg` | Free | `stg.frubble.ai` | `stg/mailgun` (`sending_key.tf`), in `stg-cd` |
| dev's own, `platform+mailgun-dev@frubble.ai` | `Mailgun - Frubble dev` | Free | `dev.frubble.ai` | `dev/mailgun` (`sending_key.tf`), in `dev-cd` |
| main, `platform+mailgun@frubble.ai` | `Mailgun - Frubble` | its own (one custom domain) | none until prd | `org/mailgun/_setup`, in `mailgun-setup-cd` |

The main account is reserved for prd: its plan allows one custom domain, and that one
is `prd.frubble.ai` once prd is turned on (getting-started.md). stg and dev each have a
free account of their own: 100 emails a day, one custom domain beside the sandbox one, no
dedicated IP, short log retention. Enough for sign-up and reset codes; a load test would
hit the daily cap. A paid plan is a dashboard change and nothing in this repository. A
domain can exist in one Mailgun account at a time.

Every account's credential for CI is its admin key, made once in its dashboard and held as
`MAILGUN_APPLY_API_KEY`: stg's account's by the `stg` environment, dev's by `dev`, the main
account's by `setup` (and by `prd` once prd is turned on). Mailgun has no narrower role
that creates domains or keys, so there is nothing to mint for CI, unlike Cloudflare. In
Bitwarden they are `Mailgun API key - stg terraform apply (stg account)`,
`Mailgun API key - dev terraform apply (dev account)` and `Mailgun API key - terraform`.
There is no `org/mailgun` live root: no account holds anything shared that the provider
manages.

## Sending keys

stg and dev: their mailgun roots are the same files but for the backend prefix
(`versions.tf`), and so is the `mailgun_writes_email_key` block in their GCP roots'
`secrets.tf`; change one, change the other. The mailgun root mints the key with the
environment's own admin key in the same apply that registers the domain, and writes it
into the secret. Its federated identity may add and destroy versions of that one secret and
read none (`roles/secretmanager.secretVersionManager`, granted by the GCP root, which the
same `<env>-cd` run applies first). The key is also in the mailgun root's state, which
only that identity and the bootstrap admin read, and that identity already holds the
account's admin key.

prd: `org/mailgun/_setup` mints one key per domain it lists, with the main account's admin
key, and keeps it in its own state, which no CI identity can read. It runs in
`mailgun-setup-cd` behind the same reviewer as the GCP `_setup` roots, after the `stg-cd`
run on the same commit (the wait in that workflow). Its `sending_domains` is empty until
prd is turned on.

A worker instance reads the secret when it starts and keeps that key until it stops, so a
rotation keeps two keys alive: add the next generation in the root that mints it (the
secret moves to it), roll the worker, then remove the old one; the comment in
`sending_key.tf` (or `org/mailgun/_setup/main.tf`) spells the steps.

## Moving stg to its own account (once)

`stg.frubble.ai` was registered in the main account, and `org/mailgun/_setup` keyed it.
The pull request that moved stg's code to `sending_key.tf` also emptied `sending_domains`.
Because a domain can be in one account only, the move is delete-then-create, and stg
cannot send mail between the delete and the roll in step 7. The worker answers anything
but 204 when a send fails, so Pub/Sub retries (10 s backoff growing to 600 s, 5 attempts,
roughly five minutes) and then dead-letters, which alerts; dead-lettered messages are
re-published by hand once stg sends again. Keep the window short by running the steps back
to back.

1. Merge the pull request. `stg-cd`, `dev-cd` and `mailgun-setup-cd` start; `stg-cd`'s
   jobs and `mailgun-setup-cd` wait for approval. Approve nothing yet.
2. Switch the `stg` environment's `MAILGUN_APPLY_API_KEY` to the stg account's admin key
   (Bitwarden `Mailgun API key - stg terraform apply (stg account)`), with nothing printed:
   `bw get item <id> | jq -r .login.password | gh secret set MAILGUN_APPLY_API_KEY --env stg --repo frubble-ai/platform`.
   A job reads an environment secret when it starts, so the waiting jobs get the new key.
3. Delete `stg.frubble.ai` from the main account (stg's mail stops here):
   `curl -s --user "api:$MAIN_KEY" -X DELETE https://api.mailgun.net/v3/domains/stg.frubble.ai`,
   with `MAIN_KEY` from `Mailgun API key - terraform`. This also takes the domain's sending
   key (`frubble stg worker, generation 1`) and its logs and stats with it.
4. Approve `stg-cd`'s `apply stg gcp` job (the plan adds `mailgun_writes_email_key`),
   then `apply stg mailgun`. Its refresh finds no `stg.frubble.ai` in the stg account and
   drops it from state; the plan is 5 to add, 1 to destroy: the domain in the stg account,
   its sending key, `terraform_data.sending_key_identity`, the secret's new version, and
   the handoff object replaced (new DKIM). No `state rm` and no `removed` block is needed.
   If that job fails with a 403 on the secret, the binding had not propagated: re-run the
   failed jobs. Then approve `apply stg cloudflare`, which updates the DKIM record
   (`mg._domainkey.stg.frubble.ai`); SPF and DMARC do not change.
5. Approve `mailgun-setup-cd`'s `apply mailgun setup` job. Its `wait` job waits for
   `stg-cd`'s mailgun job on the same commit and asks for approval only once that has
   succeeded, so the new version is `latest` by now (if the mailgun job failed first, the
   wait fails too: re-run `mailgun-setup-cd` after the re-run succeeded). Its
   plan is 3 to destroy (fewer if refresh already dropped the deleted key): the old key,
   its `terraform_data`, and the old secret version, which is no longer `latest`.
6. Verify the domain in the stg account:
   `curl -s --user "api:$STG_KEY" -X PUT https://api.mailgun.net/v4/domains/stg.frubble.ai/verify`
   shows `state: active` with SPF and DKIM `valid`. If not yet, DNS has not caught up:
   repeat in a minute.
7. Roll the stg worker (redeploy `backend-stg` from frubble-ai/app's Actions) so it reads
   the new key. Send one email through stg (a sign-up or reset code), see it under the
   stg account's logs, and re-publish anything on the dead-letter subscription.
8. Afterwards, in the main account, delete any key that was only stg's or dev's (the
   superseded `Mailgun API key - dev terraform apply` key), and note in Bitwarden that
   `Mailgun API key - stg (frubble_stg_email_api-key)` is superseded.

If `apply stg mailgun` runs before step 3, Mailgun refuses the domain (it is taken by
another account) and the job fails with nothing changed; do step 3 and re-run the failed
jobs.

## Plans and records

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

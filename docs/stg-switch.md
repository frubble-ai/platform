# Switching stg off and on

stg can be destroyed when nobody is using it and rebuilt from the same code when
someone needs it, to stop paying for it in between. The code never changes: one
variable decides whether stg's running resources exist.

## The switch

`STG_ENABLED`, a repository variable. Only the exact, lowercase `false` is off; unset or anything else (`FALSE` included) is on. The value is compared in a shell step, not in an Actions expression, because expressions compare strings case-insensitively. `stg-cd`
and the pull-request plans (`Plan stg`, `Plan stg cloudflare`) pass it to the roots
as `enabled` (`stack_switch` in the reusable workflows, resolved there in a shell step), so every run, a push to
`dev` included, plans towards what it says. Anyone with write access to the
repository can change a variable; the workflows' own tokens can't.

In the roots it is OpenTofu's `lifecycle { enabled = var.enabled }` on each module
and resource that goes. A disabled module is `null`, so everything that reads one
checks `var.enabled` first or uses `try()`. The outputs are `null` while stg is off.

## What goes and what stays

Off destroys, in `stg/gcp`: the Cloud SQL instances (the application's and osiris's, with their data and backups), the
migration job, the api, app and worker services, osiris's serve and worker services,
its migration job, its Cloud Tasks queue, its events topic and its own Cloud SQL instance,
the email queue and its alert, the load balancer with its certificates and
address, Cloud Armor, the alerts, the registry with its images, the deploy
identity's grants on all of those, the generated secrets (database password, auth
secret, and osiris's database password, API key, admin key and encryption key),
and the handoff object. In `stg/cloudflare`: the api, app and osiris A records
and their certificate authorizations.

Stays: `stg/gcp/_setup` (the project, the state bucket and its keys, the service
accounts and deploy identities, osiris's included), the network and its private
service connection (free, and deleting a peering right after Cloud SQL tends to
fail), the Pub/Sub service identity, the Composio and email key secrets with their
values and bindings, the deploy trust (the application's and osiris's),
`stg/mailgun` (the domain and its sending key) and the email DNS records.

The database starts empty after a rebuild: the backend's next deploy runs the
migrations. To keep data across a switch, export it before switching off
(`gcloud sql export sql`) and import it after; nothing here does that.

## Switching off

1. `gh variable set STG_ENABLED --body false --repo frubble-ai/platform`
2. Actions, `stg-switch`, `state: off` (frubble-ai's members only). It checks the
   variable and starts `stg-cd` on `dev`. Running `stg-cd` by hand does the same, as
   long as it's on the `dev` branch, the reviewed code:
   `gh workflow run stg-cd.yml --ref dev --repo frubble-ai/platform`.
   Off runs in the reverse order of on: `stg/cloudflare` removes the DNS records
   first, without waiting on GCP or Mailgun. Then the run waits out the records'
   300-second TTL, and only after that does `stg/gcp` release the load balancer's
   address, so no public name points at an address stg no longer holds. A re-run
   fails if `STG_ENABLED` has changed since the run started; start a new one.
3. Read the plan: only the resources above, destroyed. Nothing in `_setup`, nothing
   in mailgun.

While off, stg's application deploys (`Backend - CD`, `App - CD` and `DB - Reset` on
the app repository's `stg` branch) and osiris's (`osiris-cd` on the osiris
repository's `stg` branch) have nothing to deploy to and fail.

## Switching on

1. `gh variable set STG_ENABLED --body true --repo frubble-ai/platform`
2. `stg-switch` with `state: on`. The plan rebuilds what went: 15 to 30 minutes,
   Cloud SQL being the slow part. The certificates issue against the new
   authorization records over the following minutes.
3. Run `stg-cd` again once the certificates are active, or wait for the next push:
   a hostname's A record is published only once the load balancer serves TLS for it
   (crossing-roots.md).
4. Deploy the application to stg (its `Backend - CD` and `App - CD`), which also
   runs the migrations. Until then the services run the placeholder image.
   Osiris is the same: its `osiris-cd` on the `stg` branch. The rebuilt
   databases are empty and the encryption key is a new one.

Cloud SQL keeps a deleted instance's name for up to a week. To switch on sooner
than that after switching off, set `database_instance_suffix` (it names both instances) in
`terraform/live/stg/gcp/variables.tf` to something new (`"-2"`) in a pull request
first. Osiris's Cloud Tasks queue is the same: it keeps a deleted queue's name for
up to 3 days, so set `queue_name_suffix` there too.

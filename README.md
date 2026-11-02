# platform

Terraform for [`app`](https://github.com/frubble-ai/app): the API as a Cloud Run service behind
a Google load balancer with Cloud Armor, its Postgres database on a private network, the
migration job the deploy runs first, the email queue and the worker service that drains it,
and the keyless identities CI uses.

## Layout

```
terraform/
  live/
    org/gcp/_setup            projects, state bucket, identity pool, hubs
    org/cloudflare/_setup     zone-wide settings and the plan token
    org/cloudflare            DNS shared by every environment
    org/posthog               the PostHog project
    org/mailgun/_setup        the sending keys the workers use, written into each environment's secret
    stg/shared                what every stg root agrees on: its name, zone and hostnames; no state
    stg/gcp/_setup            stg state bucket, spokes, deny policies
    stg/gcp                   the stg API service, load balancer, WAF, alerts, registry, network, database, secrets, migration job, email queue, worker service, and the trust rules of its deploy identities
    stg/cloudflare            the stg API's DNS: its A record, its certificate authorization, and the sending domain's SPF, DKIM and DMARC
    stg/mailgun               the stg sending domain at Mailgun
    prd/…                     the same, not yet applied
  modules/                    shared code, no state. gcp/cloud-run-service, gcp/https-load-balancer, gcp/cloud-armor and gcp/alerts are the API's stack; gcp/network, gcp/cloud-sql-postgres and gcp/cloud-run-job its database and migration; gcp/pubsub-queue the email queue; naming the rule the shared/ modules derive their names with
```

One root per scope and provider, one state each.

## Shared values

Placement follows one rule, the application's: a value one root needs lives in that root; a
value several roots of an environment agree on lives in that environment's `shared/`; the
derivation both environments share lives in `modules/`. Roots cannot read each other's state,
so `live/<env>/shared` is a module with no provider and no state that each root of the
environment calls, and `modules/naming` is where the environment name and the zone become
the resource prefix, the API hostname (`api.stg.frubble.ai`) and the sending domain
(`stg.frubble.ai`, a subdomain, never the apex). Nothing in them is secret, and a change to
`shared/` is in scope for every plan of that environment. What crosses between roots is only
what one root *produces* and another needs, and it crosses as a handoff object (Crossing
roots, below), never as a repository variable.

## Crossing roots

A value one root produces and another needs is written by the producer, during its apply,
as one JSON object in the management bucket under the consumer's own prefix:
`<env>/cloudflare/handoff/gcp.json`, `<env>/cloudflare/handoff/mailgun.json`. The consumer
lists that prefix and reads what is there; an object that does not exist yet, before its
producer's first apply, feeds nothing, and the resources it feeds do not exist yet either. The
producer's apply identity may write its one object and nothing else under that prefix, which
holds the consumer's state; the consumer's identities read the prefix already, since it is
theirs. The workflow runs the consumer after its producers, so one run carries a value from
the root that makes it to the root that publishes it.

No repository variable ever carries a Terraform output to another root. A variable is set
by a person, so it drifts from the output it copies, it is read at the start of a run so it
lags the apply that changed it, and nothing reviews it. The variables that remain are CI's
own configuration: which identities to sign in as, which projects and buckets exist, which
features are switched on. The exception is `_setup` outputs copied once at bootstrap, before
any pipeline exists to carry them.

The GCP workload root hands the Cloudflare root two values. `certificate_dns_authorization`:
the Cloudflare root publishes that CNAME, DNS-only, and Certificate Manager issues the load
balancer's certificate against it; the record is permanent, since renewals reuse it.
`load_balancer_ip`: the hostname's A record, DNS-only too, since proxied every client would
arrive from Cloudflare's addresses and Cloud Armor's per-IP limit would be one budget for all
of them. Both arrive in one object, so a new environment's hostname serves Certificate
Manager's provisioning certificate for the minutes until the authorization is seen, and
nothing points at that hostname yet. The Cloud Run service and the migration job start on a
placeholder image; the application's deploy replaces it and Terraform ignores the image from
then on.

The database is a Cloud SQL Postgres instance with a private address only, in the
environment's VPC, reached by the service and the job through direct VPC egress and TLS
against the instance's own CA, which the root passes to them as `DB_CA_PEM`. No person
reaches the database: there is no public address and no bastion; the migration job and the
application are its only clients.

Email leaves through a Pub/Sub topic the API publishes to. A push subscription posts each
message to the worker, a second Cloud Run service on the same image started as the worker,
reachable by Pub/Sub's identity and nothing else: its run.app URL exists, its ingress admits
same-project Google services only, and its invoker check holds every caller to the push
identity. The worker answers 204 once the email is sent; anything else is redelivered with
backoff, and after five refusals the message moves to the dead-letter topic, whose backlog
raises the one alert this stack adds. The worker holds the email provider's key and no
database access.

## Email

Mail goes out through Mailgun, in the shape every provider here has. `stg/mailgun` and
`prd/mailgun` each register one sending domain, their state in the management bucket under
`<env>/mailgun/`. `org/mailgun/_setup` mints one sending key per domain (role `sending`,
scoped to that domain, the worker's only credential) and writes it into the environment's
`email/api-key` secret through a write-only attribute, so no key is printed or copied; it
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

The three roots are the exception to "planned on every pull request". Mailgun has no
read-only key: even its least role reads stored messages and logs, so a plan key would be a
credential reachable from an unreviewed branch, and the same identity could read the root's
state, where the provider records the domain's SMTP password and the sending keys. Instead
the apply on merge plans and applies in one job, as every apply does, and no identity
reachable from a pull request holds a Mailgun key or reads a mailgun state prefix. Nothing
uses SMTP; resetting that password in the dashboard kills the recorded one.

The sending domain comes from the environment's `shared/` (Shared values, above): the
mailgun root registers it, the Cloudflare root publishes its records, the GCP root hands it
to the worker, and none of the three spells it.

The records receivers check are the Cloudflare root's: SPF and DMARC are fixed text, and
DKIM, the one record only Mailgun can give, is the mailgun root's handoff to it (Crossing
roots, above), published by the Cloudflare apply that follows the mailgun one in the same
run. `MAILGUN_ENABLED` turns the mailgun applies on once the admin key is in the
environments; until then they report nothing. The Mailgun provider records the
domain's SMTP password in state; nothing here uses SMTP, and resetting it in the dashboard
kills the recorded one.

## Secrets

Two kinds, told apart in the workload root's `secrets.tf`. A value Terraform can generate
(the database password, the auth secret) is generated during the apply by an ephemeral
`random_password` and written through write-only attributes, to Secret Manager and, for the
password, to the database user in the same run. Neither value is ever in state or in a plan;
what state records is `secrets_version`, the number that pins them. Bumping it in a pull
request rotates both: the apply generates new values, writes them, and the services pick
them up on their next revision. A value that comes from outside (the email provider's API
key) gets a container and a placeholder from Terraform, and the root that holds the value
writes the real version the same write-only way (`org/mailgun/_setup`, Email above). Each
service reads only the secrets bound to its identity, per secret.

## How CI authenticates

GitHub OIDC → identity pool → **hub** service account (no permissions) → impersonates the
**spoke** in the target project. Trust rules match the repo, the workflow file, the
environment and the branch exactly. The rules for CI's own plan and apply hubs live in
`org/gcp/_setup`; the rules for an environment's deploy identities (the app deploy) live in
that environment's workload root, so a renamed workflow is a planned, CI-applied change. The `_setup` roots are the one exception to the hub and spoke
shape: their plan identity and the bootstrap admin act on the management project directly,
with no hub in between, since the management project is what they change. Cloudflare and
PostHog have no federation, so they use tokens stored as GitHub secrets.

The identities a workload runs as (the API's service account) are created in the
environment's `_setup` root and bound in the workload root. Owning an identity means
creating it and granting `actAs` on it, which is `serviceAccountAdmin`; that role also edits
the IAM policy of every other account in the project, the spoke's own trust binding included,
and IAM conditions cannot name a service account, so it cannot be narrowed to a prefix.

## Bootstrap

The three GCP `_setup` roots are applied by hand exactly once, as the bootstrap service
account from `.envrc.local` (copy `.envrc.local.example`). After that they are planned on
every pull request (`Plan * setup`) and applied on merge by `setup-cd`, which waits in the
`setup` environment for a reviewer. The hand path stays for that first apply and for an
emergency. `org/cloudflare/_setup` stays by hand: it needs the Cloudflare bootstrap token,
which is never stored in GitHub. `org/mailgun/_setup` runs the same way in
`mailgun-setup-cd`, with the Mailgun admin key from the `setup` environment and no
pull-request plan (Email, above).

Where a `_setup` root's inputs come from changes once. The first apply reads a
`terraform.tfvars` copied from the example, because the repository variables do not exist
yet. Step 4 copies those values into the variables. From then on CI reads the variables,
and so does every hand apply, as `TF_VAR_*` in the environment; the file is deleted, or a
stale copy rewrites what CI last applied. The mapping: `TF_SETUP_ORG_ID` (`org_id`),
`TF_SETUP_BILLING_ACCOUNT` (`billing_account`), `TF_SETUP_DEVELOPER_GROUP`
(`developer_group`), `TF_SETUP_ADMINISTRATOR` (`administrator`), `GCP_MANAGEMENT_PROJECT`
(`management_project_id`), `GCP_PROJECT_STG` and `GCP_PROJECT_PRD` (`environment_projects`),
`BACKEND_REPOSITORY` (`backend_repository`), and this repository's owner and name
(`github_owner`, `platform_repository`). `gh variable list` prints them.

1. Create the management project and the developer Google Group.
2. Apply `org/gcp/_setup` without a backend, then migrate its state into the bucket it
   created.
3. Apply `org/cloudflare/_setup`, `stg/gcp/_setup`, `prd/gcp/_setup`, each with its own
   `terraform.tfvars` from the example, for this first time only.
4. Copy the outputs into GitHub repository variables (including `PLAN_STORE_BUCKET`,
   `GCP_SETUP_PLAN_IDENTITY` and `GCP_BOOTSTRAP_SERVICE_ACCOUNT`), the `_setup` inputs as
   `TF_SETUP_ORG_ID`, `TF_SETUP_BILLING_ACCOUNT`, `TF_SETUP_DEVELOPER_GROUP`,
   `TF_SETUP_ADMINISTRATOR`, `GCP_MANAGEMENT_PROJECT` and `BACKEND_REPOSITORY`, and the
   secrets: `CLOUDFLARE_PLAN_TOKEN`,
   `POSTHOG_PLAN_API_KEY`, `POSTHOG_OWNER_EMAIL` and `POSTHOG_MEMBERS` on the repo;
   `CLOUDFLARE_MINT_TOKEN` and `POSTHOG_APPLY_API_KEY` on their environments, and the
   Mailgun admin key as `MAILGUN_APPLY_API_KEY` on `setup` and on every environment that
   applies a mailgun root: `stg` today, `prd` before `TF_APPLY_ENABLE_PRD` is turned on,
   since `MAILGUN_ENABLED` is one switch for both and a prd apply without its key fails.
5. Email, in this order, since each step needs the one before: set the repository variable
   `MAILGUN_ENABLED` to `true` (a repository variable, not an environment one: the jobs it
   gates read it before any environment is attached) and run `stg-cd` by hand
   (Actions → stg-cd → Run workflow), which registers the domain and publishes its DKIM
   record; run `mailgun-setup-cd` by hand and approve it, which mints the domain's sending
   key and writes it into `email/api-key` (Secret Manager id `frubble_<env>_email_api-key`:
   the module joins the path with underscores, since an id cannot hold `/`). A variable
   change starts no workflow on its own. The generated secrets (Secrets, above) need
   nothing. Turning prd on later is the same in this order: the admin key on `prd`, then
   `TF_APPLY_ENABLE_PRD` and a `prd-cd` run, which registers the domain, then a pull
   request adding `prd` to `sending_domains` in `org/mailgun/_setup`, whose merge mints the
   key and writes it, then a roll of the prd worker, which holds its placeholder until
   then. The setup root keys every domain it lists, so the domain must exist before it is
   listed. A service reads a secret when an
   instance starts, so a new value is live on the next revision, which the next deploy
   creates.
6. Sign up at PostHog with the owner account (never managed by Terraform; its email
   goes in `POSTHOG_OWNER_EMAIL`), create the two personal API keys, invite the
   human members, and once they have joined list them in `POSTHOG_MEMBERS` as a JSON
   object keyed by handle:
   `{"daniel":{"email":"...","level":"admin"},"alex":{"email":"...","level":"member"}}`
   (see `org/posthog/main.tf`).

Environments `stg`, `prd`, `cloudflare-org`, `posthog-org` and `setup` must exist and
accept deployments from `dev` only; `setup` also requires a reviewer and bars self-review,
which `_setup-apply.yml` checks before it runs. Their names are part of the trust rules,
and so is the `backend-stg` environment on `app`, which accepts deployments from `stg`
only.

## Pipelines

| Workflow       | When           | What                                                  |
| -------------- | -------------- | ----------------------------------------------------- |
| `live-plan`    | every PR       | plans every stack, one comment with a section each    |
| `code-quality` | every PR       | fmt, validate, tflint, actionlint, gitleaks, trivy     |
| `pr-template`  | every PR, edits | conventional title on every PR; every template section filled and checklist answered, except for bots |
| `stg-cd`       | merge to `dev` | applies stg GCP, Cloudflare and Mailgun                 |
| `org-cd`       | merge to `dev` | applies org Cloudflare and PostHog                    |
| `setup-cd`     | merge to `dev` | applies the three GCP `_setup` roots, once a reviewer approves the run |
| `mailgun-setup-cd` | merge to `dev` | applies the Mailgun `_setup` root, once a reviewer approves the run |
| `prd-cd`       | merge to `dev` | the same three for prd, behind `TF_APPLY_ENABLE_PRD`; off |

Required checks: `Plan stg / plan`, `Plan prd / plan`, `Plan org setup / plan`, `Plan stg setup / plan`, `Plan prd setup / plan`, `Code Quality Summary`, `pr template`.

## Human access

`gcloud auth login`, no keys. The developer group is read-only and cannot read secret
values. One named administrator has full access. Nobody gets a shell.

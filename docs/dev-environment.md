# The dev environment

dev is a full copy of stg: its own GCP project (`frubble-dev`), state bucket, keys,
spokes and deploy hub; its own hostnames under the shared zone (`api.dev.frubble.ai`,
`app.dev.frubble.ai`); its own Mailgun sending domain (`dev.frubble.ai`) with its own
sending key, SPF, DKIM and DMARC; its own Composio project key and auth configs; and its
own GitHub environment, `dev`, holding its own Cloudflare mint token and Mailgun key.
Its Mailgun is a separate account too (below). Nothing in dev reads or sends with
anything of stg's. The names come from
`modules/naming` (shared-values.md), so nothing below spells them.

It lands as four pull requests, each applied before the next is merged, because each
needs what the one before created:

| PR | What | Applied by |
| -- | ---- | ---------- |
| 1  | `org/gcp/_setup` and `organization-member-access` learn about dev: the project, its plan and apply hubs, its deploy hub, its state and handoff grants, human access | `setup-cd` (org), `organization-member-access-cd` |
| 2  | `dev/gcp/_setup`: state bucket, keys, spokes, runtime identities, deny policies | `setup-cd` (dev) |
| 3  | `dev/shared`, `dev/gcp`, `dev/cloudflare`, `dev/mailgun`, `dev-cd`, the dev plans | `dev-cd` |
| 4  | `dev/mailgun` mints dev's sending key in dev's Mailgun account and writes its secret; `dev/gcp` lets it | `dev-cd` |

The switches, all repository variables, none set until its step:

- `GCP_PROJECT_DEV`: dev joins every `environment_projects` map the `_setup` workflows
  build, and the dev setup plan and apply run. Unset, the map is stg and prd only.
  Once the project exists, never unset it (see Rolling back).
- `GCP_SETUP_DISABLE_DEV`: `true` pauses the dev setup plan (it passes, planning
  nothing) and the dev `setup-cd` job. dev stays in `environment_projects`.
- `TF_PLAN_ENABLE_DEV`: the dev GCP and Cloudflare plans on pull requests.
- `TF_APPLY_ENABLE_DEV`: `dev-cd`.

## dev's Mailgun account

`dev.frubble.ai` is not in the main Mailgun account (`platform+mailgun@frubble.ai`): that
account's plan allows one custom domain, and it is stg's. dev has a free account of its
own:

- Login: `platform+mailgun-dev@frubble.ai`, in Bitwarden as `Mailgun - Frubble dev`. US
  region. Activating it took a mobile number (Mailgun's anti-abuse check).
- Free plan: 100 emails a day, one custom domain (`dev.frubble.ai`) beside the sandbox
  domain, no dedicated IP, short log retention. Enough for dev's sign-up and reset codes;
  a dev load test would hit the daily cap. Moving to a paid plan is a dashboard change and
  nothing in this repository.
- Its admin key, named for dev terraform apply, is dev's `MAILGUN_APPLY_API_KEY`, in
  Bitwarden as `Mailgun API key - dev terraform apply (dev account)`. It is the account's
  only credential CI holds: `dev/mailgun` registers the domain and mints the worker's
  sending key with it (email.md). The sending key itself is in no vault: it goes from
  Mailgun straight into `frubble_dev_email_api-key`.
- `org/mailgun/_setup`, `mailgun-setup-cd` and the `setup` environment's key are the main
  account's and know nothing of dev.

## Bootstrap, in order

Before PR 1 merges

1. Pick the project id. `frubble-dev` is what the example files say; project ids are
   global, so if it is taken use another and put that in `GCP_PROJECT_DEV` (nothing in
   code spells it).
2. Create the GitHub environment `dev` on this repository, deployments from the `dev`
   branch only, like `stg`.
3. In `dev`, add its own secrets, made fresh for dev and never copied from `stg`:
   - `CLOUDFLARE_MINT_TOKEN`: a new account token from the Create Additional Tokens
     template (Manage Account → API Tokens), as for stg (org/cloudflare/_setup).
   - `MAILGUN_APPLY_API_KEY`: the admin-role key of dev's own Mailgun account (see dev's
     Mailgun account above), never the main account's. Mailgun has no narrower role
     that creates domains (email.md).

PR 1, then

4. Merge. `setup-cd` applies `org/gcp/_setup` with no dev yet, adding only the dev
   state and handoff grants, which name identities nothing can become until dev exists.
5. Set `GCP_PROJECT_DEV`, run `setup-cd` by hand (Actions → setup-cd → Run workflow)
   and approve it. The org job creates the project on the billing account, its APIs,
   its plan and apply hubs (`frubble-dev-plan-hub`, `frubble-dev-apply-hub`), the dev
   deploy hub (`frubble-dev-deploy-hub`), the developer group's and the administrator's
   access, and the setup plan identity's read role. Set `GCP_PLAN_HUB_DEV` and
   `GCP_APPLY_HUB_DEV` from its `plan_hubs` and `apply_hubs` outputs.
6. Add `dev` levels to whoever needs them in `ORG_MEMBERS_ACCESS` and run
   `organization-member-access-cd`. It also creates dev's "developers never read a
   secret value" deny policy, so run it even with no `dev` levels.

Before PR 2 merges

7. A plan identity cannot create an empty state (state_access.tf in org/gcp/_setup),
   so create dev's setup state once, as the bootstrap admin (`.envrc.local`), from PR 2's
   branch: `terraform -chdir=terraform/live/dev/gcp/_setup init -backend-config="bucket=frubble-mgmt-tfstate"`
   then `terraform -chdir=terraform/live/dev/gcp/_setup state list` (empty). Re-run the
   PR's checks; `Plan dev setup` should only create.

PR 2, then

8. Merge. `setup-cd` applies
   `dev/gcp/_setup` after a reviewer approves: the `frubble-dev-tfstate` bucket, the
   state and secrets keys, the plan, apply and deploy spokes, the API, app, worker and
   push identities, and the deny policies. The hand path
   (`terraform.tfvars.example` there) is the fallback. Then add `Plan dev setup / plan`
   to the `protected-branches` ruleset's required checks and to pipelines.md. Not
   before: a pull request whose branch predates this one has no such job, and a
   required check that never reports blocks it.
9. Set `STATE_BUCKET_DEV`, `GCP_PLAN_SPOKE_DEV` and `GCP_APPLY_SPOKE_DEV` from its
   outputs (`state_bucket`, `plan_spoke`, `apply_spoke`).
10. Create the two empty states a plan cannot create, as the bootstrap admin, from
   PR 3's branch, with the bucket from step 9:
   `STATE_BUCKET_DEV="$(gh variable get STATE_BUCKET_DEV)"`, then
   `terraform -chdir=terraform/live/dev/gcp init -backend-config="bucket=$STATE_BUCKET_DEV"`
   and `terraform -chdir=terraform/live/dev/gcp state list` (empty), then
   `terraform -chdir=terraform/live/dev/cloudflare init -backend-config="bucket=frubble-mgmt-tfstate"`
   and `terraform -chdir=terraform/live/dev/cloudflare state list` (empty).

Before PR 3 merges

11. Create a Composio project for dev and its auth configs (one per provider stg has:
    github, linear, …). Set `COMPOSIO_AUTH_CONFIG_IDS_DEV` to its `provider=id` pairs.
12. Set `TF_PLAN_ENABLE_DEV=true` and re-run the PR's checks: `Plan dev` and
    `Plan dev cloudflare` should create the stack and the email records' placeholders.

PR 3, then

13. Set `TF_APPLY_ENABLE_DEV=true` and merge. `dev-cd` applies GCP, then Mailgun
    (registers `dev.frubble.ai` in dev's own Mailgun account and hands its DKIM over,
    since `MAILGUN_ENABLED` is already true), then Cloudflare (SPF, DMARC, DKIM, the certificate authorizations).
14. Run `dev-cd` by hand a few minutes later, once the certificates are issued, so the
    A records of `api.dev` and `app.dev` are published (crossing-roots.md).
15. Add dev's Composio project API key (secrets.md), into the project chosen in step 1
    (the `GCP_PROJECT_DEV` value), not `frubble-${ENV}`, which differs if that id was taken:
    `PROJECT="$(gh variable get GCP_PROJECT_DEV)"`, then
    `read -rs KEY && [ -n "$KEY" ] && printf '%s' "$KEY" | gcloud secrets versions add frubble_dev_composio_api-key --data-file=- --project "$PROJECT"`,
    and roll the API.
16. Check `dev.frubble.ai` shows as verified in dev's Mailgun dashboard (signed in as
    `Mailgun - Frubble dev`; SPF and DKIM published by step 13).

PR 4, then

17. Merge after step 13. `dev-cd`'s GCP job grants dev's Mailgun identity the right to
    write versions of `frubble_dev_email_api-key` (`Plan dev` shows that one binding),
    then its Mailgun job mints dev's sending key in dev's account, scoped to
    `dev.frubble.ai`, and writes it into that secret. `mailgun-setup-cd` does not run for
    it. If the Mailgun job fails with a 403 on the secret, the binding had not
    propagated yet: re-run the failed job. Roll the dev worker so it reads the key.

The application (frubble-ai/app), not this repository

18. The deploy trust rules here expect `backend-cd.yml` and `db-reset.yml` in a
    `backend-dev` environment and `app-cd.yml` in `app-dev`, from the `dev` branch.
    The app repository needs those environments (variables from the dev outputs, as
    `backend-stg` and `app-stg` have; `GCP_DEPLOY_HUB` is the full email from
    org/gcp/_setup's `backend_deploy_hubs["dev"]` output,
    `frubble-dev-deploy-hub@frubble-mgmt.iam.gserviceaccount.com`),
    workflows that deploy `dev` there, its own `COMPOSIO_API_KEY` for dev rather than
    the repository-wide one, and `dev` accepted as an `APP_ENV`. Until then the dev
    services run their placeholder images.

## Rolling back

To pause dev's setup jobs, set `GCP_SETUP_DISABLE_DEV=true`; unset it to resume.
Do not unset `GCP_PROJECT_DEV` once the project exists: dev would drop out of
`environment_projects`, the org setup plan would try to destroy the project,
`prevent_destroy` refuses it, and the org job fails, which also stops the stg and prd
setup jobs that need it. Taking dev out of management is a Terraform change first, in
the same pull request as unsetting the variable: as the
bootstrap admin, `terraform -chdir=terraform/live/org/gcp/_setup state rm 'module.environment_project["dev"]'`
to keep the project but stop managing it, or delete it deliberately after lifting
`prevent_destroy`.

That is a decommission, not a pause. Everything else org/gcp/_setup keys on
`environment_projects` goes with it on the next org apply: the dev plan, apply and
deploy hubs (`frubble-dev-*-hub@frubble-mgmt`) and their trust bindings, the human
and developer-group access on dev, and the setup plan identity's grants. Dev's CI and
the app repository's dev deploys stop working. If dev must stay deployable, keep
`GCP_PROJECT_DEV` set and use `GCP_SETUP_DISABLE_DEV` instead.

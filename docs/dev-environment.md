# The dev environment

dev is a full copy of stg: its own GCP project (`frubble-dev`), state bucket, keys,
spokes and deploy hub; its own hostnames under the shared zone (`api.dev.frubble.ai`,
`app.dev.frubble.ai`); its own Mailgun sending domain (`dev.frubble.ai`) with its own
sending key, SPF, DKIM and DMARC; its own Composio project key and auth configs; and its
own GitHub environment, `dev`, holding its own Cloudflare mint token and Mailgun key.
Nothing in dev reads or sends with anything of stg's. The names come from
`modules/naming` (shared-values.md), so nothing below spells them.

It lands as four pull requests, each applied before the next is merged, because each
needs what the one before created:

| PR | What | Applied by |
| -- | ---- | ---------- |
| 1  | `org/gcp/_setup` and `organization-member-access` learn about dev: the project, its plan and apply hubs, its deploy hub, its state and handoff grants, human access | `setup-cd` (org), `organization-member-access-cd` |
| 2  | `dev/gcp/_setup`: state bucket, keys, spokes, runtime identities, deny policies | `setup-cd` (dev) |
| 3  | `dev/shared`, `dev/gcp`, `dev/cloudflare`, `dev/mailgun`, `dev-cd`, the dev plans | `dev-cd` |
| 4  | `org/mailgun/_setup` keys `dev.frubble.ai` and writes its secret | `mailgun-setup-cd` |

The switches, all repository variables, none set until its step:

- `GCP_PROJECT_DEV`: dev joins every `environment_projects` map the `_setup` workflows
  build, and the dev setup plan and apply run. Unset, the map is stg and prd only.
- `TF_PLAN_ENABLE_DEV`: the dev GCP and Cloudflare plans on pull requests.
- `TF_APPLY_ENABLE_DEV`: `dev-cd`.

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
   - `MAILGUN_APPLY_API_KEY`: a new Mailgun key with the admin role, named for dev, in
     the same account. Mailgun has no narrower role that creates domains (email.md).

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
   (`terraform.tfvars.example` there) is the fallback.
9. Set `STATE_BUCKET_DEV`, `GCP_PLAN_SPOKE_DEV` and `GCP_APPLY_SPOKE_DEV` from its
   outputs (`state_bucket`, `plan_spoke`, `apply_spoke`).
10. Create the two empty states a plan cannot create, as the bootstrap admin:
   `terraform -chdir=terraform/live/dev/gcp init -backend-config="bucket=frubble-dev-tfstate"`
   and `terraform -chdir=terraform/live/dev/cloudflare init -backend-config="bucket=frubble-mgmt-tfstate"`,
   each followed by `terraform state list` (empty) from PR 3's branch.

Before PR 3 merges

11. Create a Composio project for dev and its auth configs (one per provider stg has:
    github, linear, …). Set `COMPOSIO_AUTH_CONFIG_IDS_DEV` to its `provider=id` pairs.
12. Set `TF_PLAN_ENABLE_DEV=true` and re-run the PR's checks: `Plan dev` and
    `Plan dev cloudflare` should create the stack and the email records' placeholders.

PR 3, then

13. Set `TF_APPLY_ENABLE_DEV=true` and merge. `dev-cd` applies GCP, then Mailgun
    (registers `dev.frubble.ai` and hands its DKIM over, since `MAILGUN_ENABLED` is
    already true), then Cloudflare (SPF, DMARC, DKIM, the certificate authorizations).
14. Run `dev-cd` by hand a few minutes later, once the certificates are issued, so the
    A records of `api.dev` and `app.dev` are published (crossing-roots.md).
15. Add dev's Composio project API key (secrets.md):
    `ENV=dev`, then the `gcloud secrets versions add "frubble_dev_composio_api-key"` line there.
16. Check `dev.frubble.ai` shows as verified in the Mailgun dashboard (SPF and DKIM
    published by step 12).

PR 4, then

17. Merge after step 13: the domain must exist before a key can be scoped to it.
    `mailgun-setup-cd` waits for `dev-cd`, mints dev's sending key and writes it into
    `frubble_dev_email_api-key`; roll the dev worker so it reads it.

The application (frubble-ai/app), not this repository

18. The deploy trust rules here expect `backend-cd.yml` and `db-reset.yml` in a
    `backend-dev` environment and `app-cd.yml` in `app-dev`, from the `dev` branch.
    The app repository needs those environments (variables from the dev outputs, as
    `backend-stg` and `app-stg` have, `GCP_DEPLOY_HUB` being `frubble-dev-deploy-hub`),
    workflows that deploy `dev` there, its own `COMPOSIO_API_KEY` for dev rather than
    the repository-wide one, and `dev` accepted as an `APP_ENV`. Until then the dev
    services run their placeholder images.

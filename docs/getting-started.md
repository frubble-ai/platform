# Getting started

The three GCP `_setup` roots are applied by hand exactly once, as the bootstrap service
account from `.envrc.local` (copy `.envrc.local.example`). After that they are planned on
every pull request (`Plan * setup`) and applied on merge by `setup-cd`, which waits in the
`setup` environment for a reviewer. The hand path stays for that first apply and for an
emergency. `org/cloudflare/_setup` stays by hand: it needs the Cloudflare bootstrap token,
which is never stored in GitHub. `org/mailgun/_setup` runs the same way in
`mailgun-setup-cd`, with the Mailgun admin key from the `setup` environment and no
pull-request plan (email.md).

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

The workload roots read one of their own: `COMPOSIO_AUTH_CONFIG_IDS_STG` and `_PRD`
(`composio_auth_config_ids`), the API's Composio auth configs as `provider=id` pairs separated by
commas (`github=ac_…,linear=ac_…`). A new provider is one more pair; a variable change starts
no workflow, so run the environment's CD by hand after editing it.

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
   `POSTHOG_PLAN_API_KEY` on the repo;
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
   change starts no workflow on its own. The generated secrets (secrets.md) need
   nothing. Turning prd on later is the same in this order: the admin key on `prd`, then
   `TF_APPLY_ENABLE_PRD` and a `prd-cd` run, which registers the domain, then a pull
   request adding `prd` to `sending_domains` in `org/mailgun/_setup`, whose merge mints the
   key and writes it, then a roll of the prd worker, which holds its placeholder until
   then. The setup root keys every domain it lists, so the domain must exist before it is
   listed. A service reads a secret when an
   instance starts, so a new value is live on the next revision, which the next deploy
   creates.
6. Sign up at PostHog with the owner account (never managed by Terraform), create the
   two personal API keys, and invite the human members (human-access.md).

Environments `stg`, `prd`, `cloudflare-org`, `posthog-org`, `setup` and
`organization-member-access` must exist and accept deployments from `dev` only; `setup` and
`organization-member-access` also require a reviewer and bar self-review,
which `_setup-apply.yml` checks before it runs. Their names are part of the trust rules,
and so is the `backend-stg` environment on `app`, which accepts deployments from `stg`
only.

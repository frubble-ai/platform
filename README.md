# platform

Terraform for [`app`](https://github.com/frubble-ai/app): the API as a Cloud Run service behind
a Google load balancer with Cloud Armor, and the keyless identities CI uses. The Cloudflare
Tunnel and the GCE instance it fronted are gone.

## Layout

```
terraform/
  live/
    org/gcp/_setup            projects, state bucket, identity pool, hubs
    org/cloudflare/_setup     zone-wide settings and the plan token
    org/cloudflare            DNS shared by every environment
    org/posthog               the PostHog project
    stg/gcp/_setup            stg state bucket, spokes, deny policies
    stg/gcp                   the stg API service, load balancer, WAF, alerts, registry, and the trust rules of its deploy identities
    stg/cloudflare            the stg API's DNS: its A record and its certificate authorization
    prd/…                     the same, not yet applied
  modules/                    shared code, no state. gcp/cloud-run-service, gcp/https-load-balancer, gcp/cloud-armor and gcp/alerts are the API's stack
```

One root per scope and provider, one state each.

The GCP workload root outputs two values for the Cloudflare root, which cross by repository
variable the way `_setup` outputs do. `certificate_dns_authorization` as
`GCP_CERT_DNS_AUTH_NAME_<ENV>` and `GCP_CERT_DNS_AUTH_TARGET_<ENV>`: the Cloudflare root
publishes that CNAME, DNS-only, and Certificate Manager issues the load balancer's certificate
against it; the record is permanent, since renewals reuse it. `load_balancer_ip` as
`GCP_LB_IP_<ENV>`: the hostname's A record, DNS-only too, since proxied every client would
arrive from Cloudflare's addresses and Cloud Armor's per-IP limit would be one budget for all
of them. Until a variable is set the root creates its record not at all. For a new environment
the order is the authorization first, the certificate active, then the A record. The
Cloud Run service starts on a placeholder image; the application's deploy replaces it and
Terraform ignores the image from then on.

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
which is never stored in GitHub.

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
   `TF_SETUP_ADMINISTRATOR`, `GCP_MANAGEMENT_PROJECT` and `BACKEND_REPOSITORY`, and the six
   secrets: `CLOUDFLARE_PLAN_TOKEN`,
   `POSTHOG_PLAN_API_KEY`, `POSTHOG_OWNER_EMAIL` and `POSTHOG_MEMBERS` on the repo;
   `CLOUDFLARE_MINT_TOKEN` and `POSTHOG_APPLY_API_KEY` on their environments.
5. Add real secret values with `gcloud secrets versions add … --data-file=-`.
   The budget in `org/gcp/_setup` needs two roles on the billing account, which no root
   manages: `roles/billing.costsManager` for the bootstrap service account and
   `roles/billing.viewer` for the setup plan identity. Grant them once, by hand, as a
   billing account administrator.
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
| `stg-cd`       | merge to `dev` | applies stg GCP and Cloudflare                          |
| `org-cd`       | merge to `dev` | applies org Cloudflare and PostHog                    |
| `setup-cd`     | merge to `dev` | applies the three GCP `_setup` roots, once a reviewer approves the run |
| `*-prd-*`      | every push     | switched off                                           |

Required checks: `Plan stg / plan`, `Plan prd / plan`, `Plan org setup / plan`, `Plan stg setup / plan`, `Plan prd setup / plan`, `Code Quality Summary`, `pr template`.

## Human access

`gcloud auth login`, no keys. The developer group is read-only and cannot read secret
values. One named administrator has full access. Nobody gets a shell.

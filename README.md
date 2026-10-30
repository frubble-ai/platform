# platform

Terraform for [`app`](https://github.com/frubble-ai/app): a Cloudflare Tunnel, a small GCE
instance behind it, and the keyless identities CI uses.

## Layout

```
terraform/
  live/
    org/gcp/_setup            projects, state bucket, identity pool, hubs
    org/cloudflare/_setup     zone-wide settings and the plan token
    org/cloudflare            DNS shared by every environment
    org/posthog               the PostHog project
    stg/gcp/_setup            stg state bucket, spokes, deny policies
    stg/gcp                   the stg instance, registry and secrets
    stg/cloudflare            stg tunnel and DNS
    prd/…                     the same, not yet applied
  modules/                    shared code, no state
```

One root per scope and provider, one state each.

## How CI authenticates

GitHub OIDC → identity pool → **hub** service account (no permissions) → impersonates the
**spoke** in the target project. Trust rules match the repo, the workflow file, the
environment and the branch exactly. Cloudflare and PostHog have no federation, so they use
tokens stored as GitHub secrets.

## Bootstrap

Done once, by hand, as the bootstrap service account from `.envrc.local` (copy
`.envrc.local.example`).

1. Create the management project and the developer Google Group.
2. Apply `org/gcp/_setup` without a backend, then migrate its state into the bucket it
   created.
3. Apply `org/cloudflare/_setup`, `stg/gcp/_setup`, `prd/gcp/_setup`, each with its own
   `terraform.tfvars` from the example.
4. Copy the outputs into GitHub repository variables (including `PLAN_STORE_BUCKET`
   from `plan_store_bucket`) and the six secrets: `CLOUDFLARE_PLAN_TOKEN`,
   `POSTHOG_PLAN_API_KEY`, `POSTHOG_OWNER_EMAIL` and `POSTHOG_MEMBERS` on the repo;
   `CLOUDFLARE_MINT_TOKEN` and `POSTHOG_APPLY_API_KEY` on their environments.
5. Add real secret values with `gcloud secrets versions add … --data-file=-`.
6. Sign up at PostHog with the owner account (never managed by Terraform; its email
   goes in `POSTHOG_OWNER_EMAIL`), create the two personal API keys, invite the
   human members, and once they have joined list them in `POSTHOG_MEMBERS` as a JSON
   object keyed by handle:
   `{"daniel":{"email":"...","level":"admin"},"alex":{"email":"...","level":"member"}}`
   (see `org/posthog/main.tf`).

Environments `stg`, `prd`, `cloudflare-org` and `posthog-org` must exist and accept
deployments from `dev` only. Their names are part of the trust rules.

## Pipelines

| Workflow       | When           | What                                                  |
| -------------- | -------------- | ----------------------------------------------------- |
| `live-plan`    | every PR       | plans every stack, one comment with a section each    |
| `code-quality` | every PR       | fmt, validate, tflint, actionlint, gitleaks, trivy     |
| `stg-cd`       | merge to `dev` | applies stg GCP and Cloudflare, writes the tunnel token |
| `org-cd`       | merge to `dev` | applies org Cloudflare and PostHog                    |
| `*-prd-*`      | every push     | switched off                                           |

Required checks: `Plan stg / plan`, `Plan prd / plan`, `Code Quality Summary`.

## Human access

`gcloud auth login`, no keys. The developer group is read-only and cannot read secret
values. One named administrator has full access. Nobody gets a shell.

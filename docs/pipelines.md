# Pipelines

| Workflow       | When           | What                                                  |
| -------------- | -------------- | ----------------------------------------------------- |
| `live-plan`    | every PR       | plans every stack, one comment with a section each    |
| `code-quality` | every PR       | fmt, validate, tflint, actionlint, gitleaks, trivy     |
| `pr-template`  | every PR, edits | conventional title on every PR; every template section filled and checklist answered, except for bots |
| `stg-cd`       | merge to `dev` | applies stg GCP, Cloudflare and Mailgun; its Mailgun job also mints stg's sending key, in stg's own Mailgun account (email.md) |
| `org-cd`       | merge to `dev` | applies org Cloudflare and PostHog                    |
| `setup-cd`     | merge to `dev` | applies the GCP `_setup` roots (dev once `GCP_PROJECT_DEV` is set), once a reviewer approves the run |
| `mailgun-setup-cd` | merge to `dev` | applies the Mailgun `_setup` root (prd's sending key in the main account; none yet), once a reviewer approves the run |
| `dev-cd`       | merge to `dev` | the same three for dev, the same way as stg, behind `TF_APPLY_ENABLE_DEV` (dev-environment.md) |
| `prd-cd`       | merge to `dev` | the same three for prd, behind `TF_APPLY_ENABLE_PRD`; off |
| `organization-member-access-cd` | by hand | applies `ORG_MEMBERS_ACCESS` (human-access.md) |
| `stg-switch`   | by hand        | switches stg off or on, after `STG_ENABLED` is set: starts `stg-cd` (stg-switch.md) |

`Plan dev` and `Plan dev cloudflare` run behind `TF_PLAN_ENABLE_DEV` and are not
required checks. `Plan dev setup` runs behind `GCP_PROJECT_DEV` and is required, like
the other setup plans.

Required checks: `Plan stg / plan`, `Plan prd / plan`, `Plan org setup / plan`, `Plan dev setup / plan`, `Plan stg setup / plan`, `Plan prd setup / plan`, `Code Quality Summary`, `pr template`.

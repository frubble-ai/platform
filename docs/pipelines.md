# Pipelines

| Workflow       | When           | What                                                  |
| -------------- | -------------- | ----------------------------------------------------- |
| `live-plan`    | every PR       | plans every stack, one comment with a section each    |
| `code-quality` | every PR       | fmt, validate, tflint, actionlint, gitleaks, trivy     |
| `pr-template`  | every PR, edits | conventional title on every PR; every template section filled and checklist answered, except for bots |
| `stg-cd`       | merge to `dev` | applies stg GCP, Cloudflare and Mailgun                 |
| `org-cd`       | merge to `dev` | applies org Cloudflare and PostHog                    |
| `setup-cd`     | merge to `dev` | applies the GCP `_setup` roots (dev once `GCP_PROJECT_DEV` is set), once a reviewer approves the run |
| `mailgun-setup-cd` | merge to `dev` | applies the Mailgun `_setup` root, once a reviewer approves the run |
| `prd-cd`       | merge to `dev` | the same three for prd, behind `TF_APPLY_ENABLE_PRD`; off |
| `organization-member-access-cd` | by hand | applies `ORG_MEMBERS_ACCESS` (human-access.md) |

Required checks: `Plan stg / plan`, `Plan prd / plan`, `Plan org setup / plan`, `Plan stg setup / plan`, `Plan prd setup / plan`, `Code Quality Summary`, `pr template`.

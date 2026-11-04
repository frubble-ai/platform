# How CI authenticates

GitHub OIDC → identity pool → **hub** service account (no permissions) → impersonates the
**spoke** in the target project. Trust rules match the repo, the workflow file, the
environment and the branch exactly. One exception: dev's app deploys (`backend-cd.yml` in
`backend-dev`, `app-cd.yml` in `app-dev`) are trusted from any branch of frubble-ai/app, through
the apply provider's `deploy_entry`, which is `apply_entry` with any `refs/heads/*` collapsed to
`branch` and the run's actor id (`actor_id`) appended; a tag or a pull request's merge ref
never matches, the repository, workflow file and environment still must, and the actor must be
one of the organization members `dev/gcp/trust.tf` lists by GitHub id (`dev_deployers`, kept in
step with the organization by hand), so an outside collaborator or a bot cannot deploy to dev. Dev's `db-reset.yml` and everything of stg's and prd's stay on
`apply_entry`, exact branch included. The rules for CI's own plan and apply hubs live in
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

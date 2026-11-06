# How CI authenticates

GitHub OIDC → identity pool → **hub** service account (no permissions) → impersonates the
**spoke** in the target project. Trust rules match the repo, the workflow file, the
environment and the branch exactly. One exception: dev's app deploys (`backend-cd.yml` in
`backend-dev`, `app-cd.yml` in `app-dev`) and osiris's (`osiris-cd.yml` in `osiris-dev`) are trusted from any branch, through
the apply provider's `deploy_entry`, which is `apply_entry` with any `refs/heads/*` collapsed to
`branch` and the run's actor id (`actor_id`) appended; a tag or a pull request's merge ref
never matches, the repository, workflow file and environment still must, and the actor must be
one of the organization members `dev/gcp/trust.tf` lists by GitHub id (`dev_deployers`, kept in
step with the organization by hand), so an outside collaborator or a bot cannot deploy to dev. A
re-run keeps its first run's actor, so frubble-ai/app's Actions policy on its deploy workflows,
and the same policy on frubble-ai/osiris's `osiris-cd.yml` and `db-reset.yml`,
lists the same members and refuses a run or re-run anyone else starts (dev-environment.md). Dev's `db-reset.yml` and everything of stg's and prd's, osiris's `osiris-stg` and osiris's `db-reset.yml` included, stay on
`apply_entry`, exact branch included. Osiris signs in through its own deploy hub and spoke, not the application's. The rules for CI's own plan and apply hubs live in
`org/gcp/_setup`; the rules for an environment's deploy identities (the app deploy) live in
that environment's workload root, so a renamed workflow is a planned, CI-applied change. The `_setup` roots are the one exception to the hub and spoke
shape: their plan identity and the bootstrap admin act on the management project directly,
with no hub in between, since the management project is what they change. Cloudflare and
PostHog have no federation, so they use tokens stored as GitHub secrets.

The apply provider also accepts frubble-ai/osiris. Its deploy hubs are
`frubble-dev-osiris-deploy-hub` and `frubble-stg-osiris-deploy-hub`, created here.
Who may become each hub is that environment's workload root, the same place the
application's deploy trust lives.
Each environment's `_setup` root creates the osiris deploy spoke, which trusts only its own
hub, and lets the apply spoke edit and the plan spoke read the policy of the osiris hub. It
also gives the apply spoke `roles/cloudtasks.admin` and the plan spoke the
`frubbleCloudTasksPolicyViewer` custom role, which reads a queue's IAM policy and nothing else.

The identities a workload runs as (the API's service account) are created in the
environment's `_setup` root and bound in the workload root. Owning an identity means
creating it and granting `actAs` on it, which is `serviceAccountAdmin`; that role also edits
the IAM policy of every other account in the project, the spoke's own trust binding included,
and IAM conditions cannot name a service account, so it cannot be narrowed to a prefix.

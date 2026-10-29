# ---------------------------------------------------------------------------
# The trust rules, written once and referenced by every hub below.
#
# Each entry is the complete set of claims that must match at the same time.
# There are no wildcards: a claim nobody anticipated cannot slip through,
# and reading this block tells you exactly who may become what.
# ---------------------------------------------------------------------------

locals {
  workflows = {
    gcp_plan         = ".github/workflows/_gcp-live-plan.yml"
    gcp_apply        = ".github/workflows/_gcp-live-apply.yml"
    cloudflare_plan  = ".github/workflows/_cloudflare-live-plan.yml"
    cloudflare_apply = ".github/workflows/_cloudflare-live-apply.yml"
    posthog_plan     = ".github/workflows/_posthog-live-plan.yml"
    posthog_apply    = ".github/workflows/_posthog-live-apply.yml"
    backend_deploy   = ".github/workflows/deploy-stg.yml"
    stg_cd           = ".github/workflows/stg-cd.yml"
    prd_cd           = ".github/workflows/prd-cd.yml"
  }

  # job_workflow_ref's path component is owner/repo/path, and the provider
  # mapping has already dropped the @ref suffix.
  wf = { for k, p in local.workflows : k => "${k == "backend_deploy" ? local.backend_repo : local.platform_repo}/${p}" }

  # Plan runs on unreviewed pull-request code, so both entry points are
  # allowed — but only through the shared plan workflow, and only read-only
  # spokes sit behind them.
  plan_entries = [
    "${local.platform_repo}|${local.wf.gcp_plan}|pull-request",
    "${local.platform_repo}|${local.wf.gcp_plan}|refs/heads/dev",
  ]

  # Apply is pinned to the branch as well. Without the ref, the same workflow
  # run from a tag or a fork would be accepted.
  apply_entries = {
    stg = ["${local.platform_repo}|${local.wf.gcp_apply}|stg|refs/heads/dev"]
    prd = ["${local.platform_repo}|${local.wf.gcp_apply}|prd|refs/heads/dev"]
  }

  cloudflare_plan_entries = [
    "${local.platform_repo}|${local.wf.cloudflare_plan}|pull-request",
    "${local.platform_repo}|${local.wf.cloudflare_plan}|refs/heads/dev",
  ]

  # org has no environment of its own, so it gets a dedicated one. stg and prd
  # reuse theirs, because the Cloudflare apply for an environment runs beside
  # that environment's GCP apply.
  cloudflare_apply_entries = {
    org = ["${local.platform_repo}|${local.wf.cloudflare_apply}|cloudflare-org|refs/heads/dev"]
    stg = ["${local.platform_repo}|${local.wf.cloudflare_apply}|stg|refs/heads/dev"]
    prd = ["${local.platform_repo}|${local.wf.cloudflare_apply}|prd|refs/heads/dev"]
  }

  # PostHog is organisation-wide like org/cloudflare, so its apply gets a
  # dedicated environment for the same reason.
  posthog_plan_entries = [
    "${local.platform_repo}|${local.wf.posthog_plan}|pull-request",
    "${local.platform_repo}|${local.wf.posthog_plan}|refs/heads/dev",
  ]

  posthog_apply_entries = ["${local.platform_repo}|${local.wf.posthog_apply}|posthog-org|refs/heads/dev"]

  # The tunnel-token step runs directly in stg-cd.yml rather than through a
  # shared workflow, so its job_workflow_ref names that file. Pointing it at
  # the apply hub would fail the exchange: that hub trusts _gcp-live-apply.yml
  # and nothing else. It gets a hub of its own, which also keeps the rule that
  # a hub grants exactly one thing.
  # One per environment, like every other hub. A single shared hub would mean
  # prd's writer trusts a claim that names stg-cd.yml — so a stg deploy could
  # become prd's writer and overwrite production's tunnel secret. That is the
  # cross-environment path the whole design exists to prevent, and it appears
  # the moment two environments share one hub.
  #
  # prd names a workflow that does not exist yet: prd is planned and never
  # applied, so nothing matches this entry today. The trust is inert until
  # someone adds prd-cd.yml, and symmetric in the meantime.
  tunnel_token_entries = {
    stg = ["${local.platform_repo}|${local.wf.stg_cd}|stg|refs/heads/dev"]
    prd = ["${local.platform_repo}|${local.wf.prd_cd}|prd|refs/heads/dev"]
  }

  # The application repository deploys from its own branch, not from dev.
  backend_deploy_entries = ["${local.backend_repo}|${local.wf.backend_deploy}|stg|refs/heads/stg"]
}

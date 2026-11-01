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
    mailgun_plan     = ".github/workflows/_mailgun-live-plan.yml"
    mailgun_apply    = ".github/workflows/_mailgun-live-apply.yml"
    posthog_plan     = ".github/workflows/_posthog-live-plan.yml"
    posthog_apply    = ".github/workflows/_posthog-live-apply.yml"
    setup_plan       = ".github/workflows/_setup-plan.yml"
    setup_apply      = ".github/workflows/_setup-apply.yml"
  }

  # job_workflow_ref's path component is owner/repo/path, and the provider
  # mapping has already dropped the @ref suffix.
  wf = { for k, p in local.workflows : k => "${local.platform_repo}/${p}" }

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

  # The sending domains are per environment, so the Mailgun apply runs in the
  # environment, beside its GCP and Cloudflare applies.
  mailgun_plan_entries = [
    "${local.platform_repo}|${local.wf.mailgun_plan}|pull-request",
    "${local.platform_repo}|${local.wf.mailgun_plan}|refs/heads/dev",
  ]

  mailgun_apply_entries = {
    stg = ["${local.platform_repo}|${local.wf.mailgun_apply}|stg|refs/heads/dev"]
    prd = ["${local.platform_repo}|${local.wf.mailgun_apply}|prd|refs/heads/dev"]
  }

  # PostHog is organisation-wide like org/cloudflare, so its apply gets a
  # dedicated environment for the same reason.
  posthog_plan_entries = [
    "${local.platform_repo}|${local.wf.posthog_plan}|pull-request",
    "${local.platform_repo}|${local.wf.posthog_plan}|refs/heads/dev",
  ]

  posthog_apply_entries = ["${local.platform_repo}|${local.wf.posthog_apply}|posthog-org|refs/heads/dev"]

  # The _setup roots themselves. Plan is reached from pull requests like every
  # other plan, and only a read-only identity sits behind it. Apply is pinned
  # to its workflow file, the `setup` GitHub environment and dev: the
  # environment is where a person approves the run before it starts.
  setup_plan_entries = [
    "${local.platform_repo}|${local.wf.setup_plan}|pull-request",
    "${local.platform_repo}|${local.wf.setup_plan}|refs/heads/dev",
  ]

  setup_apply_entries = ["${local.platform_repo}|${local.wf.setup_apply}|setup|refs/heads/dev"]

  # Not here: the entry for the backend deploy hub. It is reached by one
  # environment's deploy, so its rule changes when that environment's
  # workflows do. It lives in that environment's workload root
  # (terraform/live/<env>/gcp/trust.tf), which CI plans on every pull request
  # and applies on merge. This root creates the account (hubs.tf) and says
  # nothing about who may become it.
}

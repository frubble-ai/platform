# State access for the roots that manage nothing in Google.
#
# The Cloudflare and PostHog roots keep their state in the management bucket
# and need a Google identity only to open it. A service account in that path
# would hold no other right, so the bucket and the key name the federated
# GitHub identity directly, as Google recommends: a principalSet on the trust
# entries in entries.tf, and the credential is the short-lived federated token.
#
# objectAdmin rather than objectCreator wherever a write is granted: Terraform
# must also be able to delete the lock object it wrote, and a plan that cannot
# release its lock wedges the next run.

locals {
  # The exact object prefix each stack may touch, with the trailing slash:
  # `stg/cloudflare` without it also matches a future `stg/cloudflare-anything`,
  # so the match has to stop at a path segment.
  #
  # org is spelled out rather than derived. Its two roots sit side by side —
  # org/cloudflare/live and org/cloudflare/setup — so a prefix of
  # `org/cloudflare/` would hand the _setup state to these identities, and the
  # plan one is reachable from pull-request code. org/posthog/live follows the
  # same rule.
  direct_state_stacks = {
    cloudflare-org = { prefix = "org/cloudflare/live/", plan = local.cloudflare_plan_entries, apply = local.cloudflare_apply_entries.org }
    cloudflare-stg = { prefix = "stg/cloudflare/", plan = local.cloudflare_plan_entries, apply = local.cloudflare_apply_entries.stg }
    cloudflare-prd = { prefix = "prd/cloudflare/", plan = local.cloudflare_plan_entries, apply = local.cloudflare_apply_entries.prd }
    posthog-org    = { prefix = "org/posthog/live/", plan = local.posthog_plan_entries, apply = local.posthog_apply_entries }
  }

  direct_plan = merge([
    for stack, s in local.direct_state_stacks : {
      for entry in s.plan : "${stack}|${entry}" => {
        prefix = s.prefix
        member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.plan_entry/${entry}"
      }
    }
  ]...)

  direct_apply = merge([
    for stack, s in local.direct_state_stacks : {
      for entry in s.apply : "${stack}|${entry}" => {
        prefix = s.prefix
        member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.apply_entry/${entry}"
      }
    }
  ]...)

  # The Cloudflare stacks share one plan workflow, so the same plan principal
  # appears once per stack. Bindings without a condition are keyed by member,
  # or two resources would own one binding and the first destroy would remove
  # it from under the other.
  direct_members = toset(concat(
    [for b in values(local.direct_plan) : b.member],
    [for b in values(local.direct_apply) : b.member],
  ))
}

# Apply writes the state, so it holds objectAdmin on its prefix.
#
# Scoped to this stack's own prefix. Granted bucket-wide, these identities
# could read and overwrite org/gcp/setup and the environment _setup states —
# the files that record who is allowed to do what.
resource "google_storage_bucket_iam_member" "direct_apply_state" {
  for_each = local.direct_apply

  bucket = module.management_state.name
  role   = "roles/storage.objectAdmin"
  member = each.value.member

  condition {
    title       = "only this stack's state"
    description = "Objects under ${each.value.prefix} and nothing else."
    expression  = "resource.name.startsWith('projects/_/buckets/${module.management_state.name}/objects/${each.value.prefix}')"
  }
}

# Plan reads the state and writes only the lock — the same split as the GCP
# plan spokes. objectAdmin on the whole prefix would let pull-request code
# reach an identity that could overwrite or delete the state itself, since the
# plan workflows run on unreviewed branches.
#
# It also means a new root's first plan cannot create its empty state; the
# bootstrap admin does that once (README, Bootstrap).
resource "google_storage_bucket_iam_member" "direct_plan_reads_state" {
  for_each = local.direct_plan

  bucket = module.management_state.name
  role   = "roles/storage.objectViewer"
  member = each.value.member

  condition {
    title       = "only this stack's state"
    description = "Read objects under ${each.value.prefix}."
    expression  = "resource.name.startsWith('projects/_/buckets/${module.management_state.name}/objects/${each.value.prefix}')"
  }
}

# Terraform's GCS backend takes its lock by creating <prefix>/default.tflock
# and releases it by deleting that object. A plan that cannot release its lock
# wedges every run after it, so this one write stays.
resource "google_storage_bucket_iam_member" "direct_plan_writes_lock" {
  for_each = local.direct_plan

  bucket = module.management_state.name
  role   = "roles/storage.objectAdmin"
  member = each.value.member

  condition {
    title       = "this stack's lock only"
    description = "The .tflock object under ${each.value.prefix}, and nothing else."
    expression  = "resource.name.startsWith('projects/_/buckets/${module.management_state.name}/objects/${each.value.prefix}') && resource.name.endsWith('.tflock')"
  }
}

# Listing is a bucket operation, not an object one, so the prefix conditions
# above cannot cover it — and Terraform's GCS backend lists the bucket on init
# to enumerate workspaces. Without this the identity can read its own state
# but cannot discover that it exists, and init fails before any plan runs.
#
# legacyBucketReader is the smallest predefined role that carries
# storage.objects.list. It exposes object *names* across the bucket, which
# reveals the layout of the stacks and nothing about their contents.
resource "google_storage_bucket_iam_member" "direct_state_list" {
  for_each = local.direct_members

  bucket = module.management_state.name
  role   = "roles/storage.legacyBucketReader"
  member = each.value
}

# Reading an object from a CMEK bucket decrypts with the key, which is a
# separate permission from reading the object.
resource "google_kms_crypto_key_iam_member" "direct_state_key" {
  for_each = local.direct_members

  crypto_key_id = module.management_state.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value
}

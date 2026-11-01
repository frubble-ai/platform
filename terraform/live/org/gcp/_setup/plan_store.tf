# The private store for full plan and apply output (modules/gcp/plan-store
# explains why it exists and why it is its own bucket).
#
# Layout: <kind>/<stack>/<random id>/, with a run.txt naming the ref, run
# and commit. Random because the prefix is linked from pull-request comments
# on a public repository (plan-store-upload.sh).
#   kind  = plan | apply
#   stack = gcp-stg, gcp-prd, cloudflare-org, cloudflare-stg, cloudflare-prd,
#           posthog-org, setup-org, setup-stg, setup-prd: the keys
#           .github/scripts/pull-request/plan-comment.js labels the comment with;
#           mailgun-stg, mailgun-prd: apply output only, those roots have no
#           pull-request plan.
#
# Every grant below is additive and narrow:
#   - CI writes with objectCreator, conditioned on its own <kind>/<stack>/
#     prefix. objectCreator carries storage.objects.create and nothing else:
#     no read, no list, no overwrite, no delete. A plan identity reached from
#     pull-request code can add a file to its own plan prefix and do nothing
#     else here, and cannot touch apply records at all.
#   - Developers read the rendered text (*.txt) only. The binary tfplan holds
#     sensitive values in clear, and the developer group is the one that is
#     denied secret values, so it gets no read on tfplan.
#   - No identity other than the GCS service agent holds the bucket's key:
#     CMEK is applied by GCS on the caller's behalf.
#
# The GCP plan and apply spokes live in the environment projects, so their
# grants are made by stg/gcp/_setup and prd/gcp/_setup from this root's
# outputs, beside their existing management-bucket grants.

module "plan_store" {
  source = "../../../../modules/gcp/plan-store"

  name       = "${var.management_project_id}-tfplans"
  project_id = var.management_project_id
  location   = var.region

  labels = {
    env          = "org"
    component    = "plans"
    "managed-by" = "terraform"
  }
}

locals {
  plan_store_objects = "projects/_/buckets/${module.plan_store.name}/objects"

  # The direct (no service account) identities of the Cloudflare and PostHog
  # workflows, one binding per stack and entry, exactly as for their state.
  direct_plan_store_writers = merge(
    { for k, b in local.direct_plan : "plan|${k}" => { member = b.member, prefix = "plan/${split("|", k)[0]}/" } },
    { for k, b in local.direct_apply : "apply|${k}" => { member = b.member, prefix = "apply/${split("|", k)[0]}/" } },
  )
}

resource "google_storage_bucket_iam_member" "direct_writes_plan_store" {
  for_each = local.direct_plan_store_writers

  bucket = module.plan_store.name
  role   = "roles/storage.objectCreator"
  member = each.value.member

  condition {
    title       = "own ${trimsuffix(each.value.prefix, "/")} only"
    description = "Create objects under ${each.value.prefix} and nothing else."
    expression  = "resource.name.startsWith('${local.plan_store_objects}/${each.value.prefix}')"
  }
}

# Listing is bucket-level, so a prefix condition cannot express it (see
# state_access.tf). On this bucket it shows object names, which are stack
# names, pull-request numbers and run ids.
resource "google_storage_bucket_iam_member" "developers_list_plan_store" {
  bucket = module.plan_store.name
  role   = "roles/storage.legacyBucketReader"
  member = var.developer_group
}

resource "google_storage_bucket_iam_member" "developers_read_plan_text" {
  bucket = module.plan_store.name
  role   = "roles/storage.objectViewer"
  member = var.developer_group

  condition {
    title       = "rendered plans only"
    description = "plan.txt and apply.txt. Not tfplan, which holds sensitive values in clear."
    expression  = "resource.name.startsWith('${local.plan_store_objects}/') && resource.name.endsWith('.txt')"
  }
}

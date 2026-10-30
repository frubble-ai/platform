# Each spoke may add files to its own prefix in the private plan store
# (org/gcp/_setup/plan_store.tf has the layout and the reasoning) and nothing
# else: objectCreator cannot read, list, overwrite or delete. The plan spoke
# stays read-only towards infrastructure and state; this is the one new write
# it gets, and it can only write the record of its own plan.
locals {
  plan_store_writers = {
    plan  = module.plan_spoke.member
    apply = module.apply_spoke.member
  }
}

resource "google_storage_bucket_iam_member" "spokes_write_plan_store" {
  for_each = local.plan_store_writers

  bucket = local.org.plan_store_bucket
  role   = "roles/storage.objectCreator"
  member = each.value

  condition {
    title       = "own ${each.key}/gcp-${var.environment} only"
    description = "Create objects under ${each.key}/gcp-${var.environment}/ and nothing else."
    expression  = "resource.name.startsWith('projects/_/buckets/${local.org.plan_store_bucket}/objects/${each.key}/gcp-${var.environment}/')"
  }
}

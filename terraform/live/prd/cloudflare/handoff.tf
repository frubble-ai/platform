# What the other roots of this environment produce for this one, read back
# from the handoff objects they write under this root's prefix (README,
# "Crossing roots"): the GCP root's load balancer address and certificate
# authorization, the mailgun root's DKIM record. A root that has not applied
# yet has written nothing, and the records it feeds do not exist yet; a
# field never arrives without the others in its object.
locals {
  handoff_prefix = "${module.shared.environment}/cloudflare/handoff/"
  listed         = [for object in data.google_storage_bucket_objects.handoff.bucket_objects : object.name]
  # Each producer's current object, named by its content (`<producer>-<hash>.json`), or the fixed
  # name it had before (`<producer>.json`) when it has written none since. Only these are read,
  # whatever else the listing shows (a lock object, say). More than one fails the plan: the
  # producer's apply wrote a new one and has not yet deleted the old, and its next apply will.
  handoff_objects = {
    for producer in ["gcp", "mailgun"] : producer => one(coalescelist(
      [for name in local.listed : name if can(regex("^${local.handoff_prefix}${producer}-[0-9a-f]{16}\\.json$", name))],
      [for name in local.listed : name if name == "${local.handoff_prefix}${producer}.json"],
      [null],
    ))
  }
}

data "google_storage_bucket_objects" "handoff" {
  bucket = var.management_state_bucket
  prefix = local.handoff_prefix
}

data "google_storage_bucket_object_content" "handoff" {
  for_each = { for producer, name in local.handoff_objects : producer => name if name != null }

  bucket = var.management_state_bucket
  name   = each.value
}

locals {
  handoff = {
    for producer, object in data.google_storage_bucket_object_content.handoff :
    producer => jsondecode(object.content)
  }
  gcp     = lookup(local.handoff, "gcp", null)
  mailgun = lookup(local.handoff, "mailgun", null)
}

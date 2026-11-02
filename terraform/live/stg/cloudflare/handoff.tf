# What the other roots of this environment produce for this one, read back
# from the handoff objects they write under this root's prefix (README,
# "Crossing roots"): the GCP root's load balancer address and certificate
# authorization, the mailgun root's DKIM record. A root that has not applied
# yet has written nothing, and the records it feeds do not exist yet; a
# field never arrives without the others in its object.
data "google_storage_bucket_objects" "handoff" {
  bucket = var.management_state_bucket
  prefix = "${module.shared.environment}/cloudflare/handoff/"
}

data "google_storage_bucket_object_content" "handoff" {
  for_each = toset([for object in data.google_storage_bucket_objects.handoff.bucket_objects : object.name])

  bucket = var.management_state_bucket
  name   = each.value
}

locals {
  handoff = {
    for name, object in data.google_storage_bucket_object_content.handoff :
    trimsuffix(basename(name), ".json") => jsondecode(object.content)
  }
  gcp     = lookup(local.handoff, "gcp", null)
  mailgun = lookup(local.handoff, "mailgun", null)
}

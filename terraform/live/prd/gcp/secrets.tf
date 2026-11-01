# ---------- secrets: the containers exist here, the values never do ----------
# Values are added by a person (README, "Bootstrap"); each workload reads only
# the ones it needs, bound per secret below.
locals {
  secrets = {
    database_password = { domain = "database", name = "password" }
    auth_secret       = { domain = "auth", name = "secret" }
  }

  api_secrets = ["database_password", "auth_secret"]
}

module "secrets" {
  source   = "../../../modules/gcp/secret"
  for_each = local.secrets

  project_id  = var.project_id
  environment = var.environment
  domain      = each.value.domain
  name        = each.value.name
  location    = var.region
  kms_key     = local.setup.secrets_key
  labels      = merge(local.labels, { component = each.value.domain })
}

resource "google_secret_manager_secret_iam_member" "api_reads" {
  for_each = toset(local.api_secrets)

  project   = var.project_id
  secret_id = module.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.setup.api_service_account}"
}

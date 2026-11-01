# ---------- secrets ----------
# Two kinds (README, "Secrets"). A generated value is made here, during the
# apply, and written through write-only attributes: it reaches Secret Manager
# (and the database, for the password) and never the state. A value that
# comes from outside gets a container and a placeholder, and a person adds
# it. Each workload reads only the secrets it needs, bound per secret below.
locals {
  secrets = {
    database_password = { domain = "database", name = "password", generated = true }
    auth_secret       = { domain = "auth", name = "secret", generated = true }
    email_api_key     = { domain = "email", name = "api-key", generated = false }
  }

  api_secrets    = ["database_password", "auth_secret"]
  worker_secrets = ["email_api_key"]
}

# Made fresh on every run and recorded nowhere; only the version number is.
# The same number pins the database user's password, so both move together.
ephemeral "random_password" "database" {
  length  = 40
  special = false
}

ephemeral "random_password" "auth_secret" {
  length  = 64
  special = false
}

locals {
  generated_values = {
    database_password = ephemeral.random_password.database.result
    auth_secret       = ephemeral.random_password.auth_secret.result
  }
}

module "secrets" {
  source   = "../../../modules/gcp/secret"
  for_each = local.secrets

  project_id       = var.project_id
  environment      = var.environment
  domain           = each.value.domain
  name             = each.value.name
  location         = var.region
  kms_key          = local.setup.secrets_key
  labels           = merge(local.labels, { component = each.value.domain })
  generated        = each.value.generated
  value_wo         = each.value.generated ? local.generated_values[each.key] : null
  value_wo_version = var.secrets_version
}

resource "google_secret_manager_secret_iam_member" "api_reads" {
  for_each = toset(local.api_secrets)

  project   = var.project_id
  secret_id = module.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.setup.api_service_account}"
}

resource "google_secret_manager_secret_iam_member" "worker_reads" {
  for_each = toset(local.worker_secrets)

  project   = var.project_id
  secret_id = module.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.setup.worker_service_account}"
}

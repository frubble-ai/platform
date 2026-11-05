# ---------- secrets ----------
# Two kinds (docs/secrets.md). A generated value is made here, during the
# apply, and written through write-only attributes: it reaches Secret Manager
# (and the database, for the password) and never the state. A value that
# comes from outside gets a container and a placeholder, and a person adds
# it. Each workload reads only the secrets it needs, bound per secret below.
locals {
  secrets = {
    database_password        = { domain = "database", name = "password", generated = true, version = var.secrets_version }
    auth_secret              = { domain = "auth", name = "secret", generated = true, version = var.secrets_version }
    email_api_key            = { domain = "email", name = "api-key", generated = false, version = var.secrets_version }
    composio_api_key         = { domain = "composio", name = "api-key", generated = false, version = var.secrets_version }
    osiris_database_password = { domain = "osiris", name = "database-password", generated = true, version = var.secrets_version }
    osiris_api_key           = { domain = "osiris", name = "api-key", generated = true, version = var.secrets_version }
    osiris_admin_key         = { domain = "osiris", name = "admin-key", generated = true, version = var.secrets_version }
    # Not secrets_version: rotating the master key without re-wrapping the
    # data keys makes every stored token unreadable.
    osiris_encryption_key = { domain = "osiris", name = "encryption-key", generated = true, version = var.osiris_encryption_key_version }
  }

  # While stg is switched off (var.enabled) the generated ones go with the
  # database: a rebuilt database gets a new password, and only a secret
  # created in the same apply holds it. The ones from outside stay, with the
  # value a person or the mailgun root put there, so a rebuild needs nothing
  # re-entered. The containers cost next to nothing. Osiris's generated
  # secrets, the encryption key included, go with the database.
  active_secrets = { for key, secret in local.secrets : key => secret if var.enabled || !secret.generated }

  api_secrets             = [for key in ["database_password", "auth_secret", "composio_api_key"] : key if contains(keys(local.active_secrets), key)]
  worker_secrets          = [for key in ["email_api_key"] : key if contains(keys(local.active_secrets), key)]
  osiris_secrets          = [for key in ["osiris_database_password", "osiris_encryption_key", "osiris_api_key", "osiris_admin_key"] : key if contains(keys(local.active_secrets), key)]
  osiris_worker_secrets   = [for key in ["osiris_database_password", "osiris_encryption_key"] : key if contains(keys(local.active_secrets), key)]
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

ephemeral "random_password" "osiris_database" {
  length  = 40
  special = false
}

ephemeral "random_password" "osiris_api_key" {
  length  = 64
  special = false
}

ephemeral "random_password" "osiris_admin_key" {
  length  = 64
  special = false
}

ephemeral "random_password" "osiris_encryption_key" {
  length  = 64
  special = false
}

locals {
  generated_values = {
    database_password        = ephemeral.random_password.database.result
    auth_secret              = ephemeral.random_password.auth_secret.result
    osiris_database_password = ephemeral.random_password.osiris_database.result
    osiris_api_key           = ephemeral.random_password.osiris_api_key.result
    osiris_admin_key         = ephemeral.random_password.osiris_admin_key.result
    osiris_encryption_key    = ephemeral.random_password.osiris_encryption_key.result
  }
}

module "secrets" {
  source   = "../../../modules/gcp/secret"
  for_each = local.active_secrets

  project_id       = var.project_id
  environment      = module.shared.environment
  domain           = each.value.domain
  name             = each.value.name
  location         = var.region
  kms_key          = local.setup.secrets_key
  labels           = merge(local.labels, { component = each.value.domain })
  generated        = each.value.generated
  value_wo         = each.value.generated ? local.generated_values[each.key] : null
  value_wo_version = each.value.version
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

resource "google_secret_manager_secret_iam_member" "osiris_reads" {
  for_each = toset(local.osiris_secrets)

  project   = var.project_id
  secret_id = module.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.setup.osiris_service_account}"
}

resource "google_secret_manager_secret_iam_member" "osiris_worker_reads" {
  for_each = toset(local.osiris_worker_secrets)

  project   = var.project_id
  secret_id = module.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.setup.osiris_worker_service_account}"
}

# The Mailgun sending key is minted by this environment's own mailgun root, in
# the environment's own Mailgun account (docs/email.md), not by
# org/mailgun/_setup. That root signs in as the federated GitHub identity of
# its apply entry, with no service account, so the right to write the key
# names that entry, the same one state_access.tf in org/gcp/_setup grants the
# environment's Mailgun state to. secretVersionManager adds, lists and
# destroys versions and never reads one: secretmanager.versions.access is not
# in it. On this one secret only. The same block in dev/gcp and stg/gcp.
locals {
  mailgun_apply_entry = join("|", [
    local.setup.repositories.platform,
    "${local.setup.repositories.platform}/.github/workflows/_mailgun-live-apply.yml",
    module.shared.environment,
    "refs/heads/dev",
  ])
}

resource "google_secret_manager_secret_iam_member" "mailgun_writes_email_key" {
  project   = var.project_id
  secret_id = module.secrets["email_api_key"].secret_id
  role      = "roles/secretmanager.secretVersionManager"
  member    = "principalSet://iam.googleapis.com/${local.setup.workload_identity_pool}/attribute.apply_entry/${local.mailgun_apply_entry}"
}

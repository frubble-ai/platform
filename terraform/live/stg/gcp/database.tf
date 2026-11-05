# ---------- the database, on the environment's own network ----------
module "network" {
  source = "../../../modules/gcp/network"

  project_id = var.project_id
  name       = local.name
  region     = var.region
}

module "database" {
  source = "../../../modules/gcp/cloud-sql-postgres"

  project_id        = var.project_id
  name              = "${local.name}-postgres${var.database_instance_suffix}"
  region            = var.region
  network_id        = module.network.network_id
  high_availability = module.shared.environment == "prd"
  # A week in stg; prd keeps a month, the longest a mistake has gone unnoticed
  # in anyone's experience.
  backup_retention_days = module.shared.environment == "prd" ? 30 : 7
  database_name         = "frubble"
  user_name             = "frubble"
  password_wo           = local.generated_values["database_password"]
  password_wo_version   = var.secrets_version
  deletion_protection   = module.shared.environment == "prd"
  labels                = merge(local.labels, { component = "database" })

  depends_on = [module.network]

  lifecycle {
    enabled = var.enabled
  }
}

# Osiris's database and user, on the instance above. A second database, not
# a second instance. The grant job revokes CONNECT across the two.
resource "google_sql_database" "osiris" {
  project  = var.project_id
  instance = module.database.instance_name
  name     = "osiris"

  # Once the grant job has run, the osiris user owns this database. A role
  # that still owns something cannot be dropped, so the database has to be
  # destroyed before the user.
  depends_on = [google_sql_user.osiris]

  lifecycle {
    enabled = var.enabled
  }
}

resource "google_sql_user" "osiris" {
  project             = var.project_id
  instance            = module.database.instance_name
  name                = "osiris"
  password_wo         = local.generated_values["osiris_database_password"]
  password_wo_version = var.secrets_version

  lifecycle {
    enabled = var.enabled
  }
}

# Holds cloudsqlsuperuser so it can revoke CONNECT. The osiris and
# application users do not use this password.
resource "google_sql_user" "grants" {
  project             = var.project_id
  instance            = module.database.instance_name
  name                = "grants"
  password_wo         = local.generated_values["database_grants_password"]
  password_wo_version = var.secrets_version

  lifecycle {
    enabled = var.enabled
  }
}

locals {
  # What every workload that opens the database needs. The password comes
  # from Secret Manager, below, never from here. Empty while stg is switched
  # off: the database and the secret are gone, and so is everything that
  # reads these.
  database_env = !var.enabled ? {} : {
    DB_HOST   = module.database.private_ip
    DB_PORT   = "5432"
    DB_NAME   = module.database.database_name
    DB_USER   = module.database.user_name
    DB_CA_PEM = module.database.server_ca_pem
  }

  database_secret_env = !var.enabled ? {} : {
    DB_PASSWORD = { secret = module.secrets["database_password"].secret_id }
  }

  vpc = {
    network    = module.network.network_id
    subnetwork = module.network.subnetwork_id
  }
}

# ---------- the migration, as a job the deploy executes before a rollout ----------
module "migrate_job" {
  source = "../../../modules/gcp/cloud-run-job"

  project_id            = var.project_id
  name                  = "${local.name}-migrate"
  region                = var.region
  service_account_email = local.setup.api_service_account
  image                 = var.api_bootstrap_image
  command               = ["bun", "run", "scripts/migrate.ts"]
  env = merge(local.database_env, {
    APP_ENV              = module.shared.environment
    SHOULD_RUN_MIGRATION = "true"
  })
  secret_env          = local.database_secret_env
  vpc                 = local.vpc
  deletion_protection = module.shared.environment == "prd"
  labels              = merge(local.labels, { component = "migrate" })

  depends_on = [
    module.secrets,
    google_secret_manager_secret_iam_member.api_reads,
  ]

  lifecycle {
    enabled = var.enabled
  }
}

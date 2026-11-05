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
  name              = "${local.name}-postgres"
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
}

resource "google_sql_user" "osiris" {
  project             = var.project_id
  instance            = module.database.instance_name
  name                = "osiris"
  password_wo         = local.generated_values["osiris_database_password"]
  password_wo_version = var.secrets_version
}

# Holds cloudsqlsuperuser so it can revoke CONNECT. The osiris and
# application users do not use this password.
resource "google_sql_user" "grants" {
  project             = var.project_id
  instance            = module.database.instance_name
  name                = "grants"
  password_wo         = local.generated_values["database_grants_password"]
  password_wo_version = var.secrets_version
}

locals {
  # What every workload that opens the database needs. The password comes
  # from Secret Manager, below, never from here.
  database_env = {
    DB_HOST   = module.database.private_ip
    DB_PORT   = "5432"
    DB_NAME   = module.database.database_name
    DB_USER   = module.database.user_name
    DB_CA_PEM = module.database.server_ca_pem
  }

  database_secret_env = {
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
}

# Closes CONNECT between the two databases. Run once after apply, and again
# after stg is rebuilt (docs/dev-environment.md). Not part of a deploy.
locals {
  database_grants_sql = "BEGIN; GRANT CONNECT ON DATABASE frubble TO frubble; GRANT CONNECT ON DATABASE osiris TO osiris; REVOKE CONNECT ON DATABASE frubble FROM PUBLIC; REVOKE CONNECT ON DATABASE osiris FROM PUBLIC; GRANT osiris TO grants; ALTER DATABASE osiris OWNER TO osiris; REVOKE cloudsqlsuperuser FROM osiris; COMMIT;"
}

module "database_grants_job" {
  source = "../../../modules/gcp/cloud-run-job"

  project_id            = var.project_id
  name                  = "${local.name}-db-grants"
  region                = var.region
  service_account_email = local.setup.database_grants_service_account
  image                 = "mirror.gcr.io/library/postgres:16-alpine"
  command               = ["sh", "-c"]
  args = [
    "printf '%s\\n' \"$DB_CA_PEM\" > /tmp/ca.pem && psql \"host=$DB_HOST port=$DB_PORT dbname=postgres user=$DB_USER sslmode=verify-ca sslrootcert=/tmp/ca.pem\" -v ON_ERROR_STOP=1 -c \"$DATABASE_GRANTS_SQL\"",
  ]
  env = {
    DB_HOST             = module.database.private_ip
    DB_PORT             = "5432"
    DB_USER             = google_sql_user.grants.name
    DB_CA_PEM           = module.database.server_ca_pem
    DATABASE_GRANTS_SQL = local.database_grants_sql
  }
  secret_env = {
    PGPASSWORD = { secret = module.secrets["database_grants_password"].secret_id }
  }
  vpc                 = local.vpc
  deletion_protection = module.shared.environment == "prd"
  labels              = merge(local.labels, { component = "database" })

  depends_on = [
    google_sql_database.osiris,
    google_sql_user.osiris,
    google_sql_user.grants,
    module.secrets,
    google_secret_manager_secret_iam_member.database_grants_reads,
  ]
}

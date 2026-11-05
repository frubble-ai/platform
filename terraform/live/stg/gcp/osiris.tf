# ---------- osiris: public API, internal worker, migration ----------
# One image. OSIRIS_PROCESS chooses serve, worker or migrate, so nothing
# here sets a command. Both services scale to zero. Everything in this file
# goes when stg is switched off (docs/stg-switch.md).
data "google_project" "this" {
  project_id = var.project_id
}

locals {
  # Two instances, two connections each: eight connections at the ceiling,
  # on the instance the application already uses.
  osiris_max_instances   = 2
  osiris_max_connections = 2
  osiris_worker_url      = "https://${local.name}-osiris-worker-${data.google_project.this.number}.${var.region}.run.app"
  osiris_database_env = !var.enabled ? {} : {
    DB_HOST   = module.database.private_ip
    DB_PORT   = "5432"
    DB_NAME   = google_sql_database.osiris.name
    DB_USER   = google_sql_user.osiris.name
    DB_CA_PEM = module.database.server_ca_pem
  }
  osiris_database_secret_env = !var.enabled ? {} : {
    DB_PASSWORD = { secret = module.secrets["osiris_database_password"].secret_id }
  }
  osiris_runtime_env = !var.enabled ? {} : {
    LOG_FORMAT                        = "json"
    OSIRIS_PUBLIC_URL                 = "https://${module.shared.osiris_hostname}"
    OSIRIS_WORKER_URL                 = local.osiris_worker_url
    OSIRIS_TASKS                      = "cloud_tasks"
    CLOUD_TASKS_PROJECT               = var.project_id
    CLOUD_TASKS_LOCATION              = var.region
    CLOUD_TASKS_QUEUE                 = google_cloud_tasks_queue.osiris.name
    CLOUD_TASKS_SERVICE_ACCOUNT       = local.setup.osiris_tasks_service_account
    PUBSUB_PROJECT                    = var.project_id
    OSIRIS_EVENTS_TOPIC               = google_pubsub_topic.osiris_events.name
    OSIRIS__DATABASE__MAX_CONNECTIONS = tostring(local.osiris_max_connections)
  }
  osiris_task_identities = toset([
    local.setup.osiris_service_account,
    local.setup.osiris_worker_service_account,
  ])
  database_grants_sql = "BEGIN; GRANT CONNECT ON DATABASE frubble TO frubble; GRANT CONNECT ON DATABASE osiris TO osiris; REVOKE CONNECT ON DATABASE frubble FROM PUBLIC; REVOKE CONNECT ON DATABASE osiris FROM PUBLIC; GRANT osiris TO grants; ALTER DATABASE osiris OWNER TO osiris; REVOKE cloudsqlsuperuser FROM osiris; COMMIT;"
}

module "osiris_service" {
  source = "../../../modules/gcp/cloud-run-service"

  project_id            = var.project_id
  name                  = "${local.name}-osiris"
  region                = var.region
  service_account_email = local.setup.osiris_service_account
  image                 = var.api_bootstrap_image
  env = merge(local.osiris_database_env, local.osiris_runtime_env, {
    OSIRIS_PROCESS = "serve"
    OSIRIS_ENV     = module.shared.environment
  })
  secret_env = merge(local.osiris_database_secret_env, {
    OSIRIS_ENCRYPTION_KEY = { secret = module.secrets["osiris_encryption_key"].secret_id }
    OSIRIS_API_KEY        = { secret = module.secrets["osiris_api_key"].secret_id }
    OSIRIS_ADMIN_KEY      = { secret = module.secrets["osiris_admin_key"].secret_id }
  })
  vpc                 = local.vpc
  max_instances       = local.osiris_max_instances
  deletion_protection = module.shared.environment == "prd"
  labels              = merge(local.labels, { component = "osiris" })

  depends_on = [
    module.secrets,
    google_secret_manager_secret_iam_member.osiris_reads,
  ]

  lifecycle {
    enabled = var.enabled
  }
}

module "osiris_worker_service" {
  source = "../../../modules/gcp/cloud-run-service"

  project_id            = var.project_id
  name                  = "${local.name}-osiris-worker"
  region                = var.region
  service_account_email = local.setup.osiris_worker_service_account
  image                 = var.api_bootstrap_image
  env = merge(local.osiris_database_env, local.osiris_runtime_env, {
    OSIRIS_PROCESS                = "worker"
    OSIRIS_ENV                    = module.shared.environment
    OSIRIS__TASKS__MAX_CONCURRENT = tostring(local.osiris_max_connections)
  })
  secret_env = merge(local.osiris_database_secret_env, {
    OSIRIS_ENCRYPTION_KEY = { secret = module.secrets["osiris_encryption_key"].secret_id }
  })
  # Cloud Tasks calls the run.app URL with an OIDC token. Internal ingress
  # admits Cloud Tasks in this project and nothing from the internet, and
  # the invoker check holds the caller to the tasks identity. The worker
  # also checks that token, which Cloud Run passes through on Authorization.
  default_uri_disabled = false
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_iam_disabled = false
  max_instances        = local.osiris_max_instances
  concurrency          = local.osiris_max_connections
  deletion_protection  = module.shared.environment == "prd"
  labels               = merge(local.labels, { component = "osiris" })

  depends_on = [
    module.secrets,
    google_secret_manager_secret_iam_member.osiris_worker_reads,
  ]

  lifecycle {
    enabled = var.enabled
  }
}

resource "google_cloud_run_v2_service_iam_member" "tasks_invoke_osiris_worker" {
  project  = var.project_id
  location = var.region
  name     = module.osiris_worker_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.setup.osiris_tasks_service_account}"

  lifecycle {
    enabled = var.enabled
  }
}

module "osiris_migrate_job" {
  source = "../../../modules/gcp/cloud-run-job"

  project_id            = var.project_id
  name                  = "${local.name}-osiris-migrate"
  region                = var.region
  service_account_email = local.setup.osiris_service_account
  image                 = var.api_bootstrap_image
  env = merge(local.osiris_database_env, {
    OSIRIS_PROCESS                    = "migrate"
    OSIRIS_ENV                        = module.shared.environment
    LOG_FORMAT                        = "json"
    OSIRIS__DATABASE__MAX_CONNECTIONS = tostring(local.osiris_max_connections)
  })
  secret_env          = local.osiris_database_secret_env
  vpc                 = local.vpc
  deletion_protection = module.shared.environment == "prd"
  labels              = merge(local.labels, { component = "osiris" })

  depends_on = [
    module.secrets,
    google_secret_manager_secret_iam_member.osiris_reads,
  ]

  lifecycle {
    enabled = var.enabled
  }
}

# Retries until the task succeeds. max_attempts -1 is unlimited, and a zero
# max_retry_duration does not expire it. Concurrent dispatches stay at the
# worker's instance ceiling.
resource "google_cloud_tasks_queue" "osiris" {
  project  = var.project_id
  name     = "${local.name}-osiris${var.queue_name_suffix}"
  location = var.region

  rate_limits {
    max_concurrent_dispatches = local.osiris_max_instances
    max_dispatches_per_second = 5
  }

  retry_config {
    max_attempts       = -1
    max_retry_duration = "0s"
    min_backoff        = "10s"
    max_backoff        = "3600s"
    max_doublings      = 5
  }

  lifecycle {
    enabled = var.enabled
  }
}

resource "google_cloud_tasks_queue_iam_member" "osiris_enqueues" {
  for_each = var.enabled ? local.osiris_task_identities : toset([])

  project  = var.project_id
  location = var.region
  name     = google_cloud_tasks_queue.osiris.name
  role     = "roles/cloudtasks.enqueuer"
  member   = "serviceAccount:${each.value}"
}

resource "google_cloud_tasks_queue_iam_member" "osiris_deletes_tasks" {
  for_each = var.enabled ? local.osiris_task_identities : toset([])

  project  = var.project_id
  location = var.region
  name     = google_cloud_tasks_queue.osiris.name
  role     = "roles/cloudtasks.taskDeleter"
  member   = "serviceAccount:${each.value}"
}

resource "google_pubsub_topic" "osiris_events" {
  project = var.project_id
  name    = "${local.name}-osiris-events"
  labels  = merge(local.labels, { component = "osiris" })

  lifecycle {
    enabled = var.enabled
  }
}

resource "google_pubsub_topic_iam_member" "osiris_publishes" {
  for_each = var.enabled ? local.osiris_task_identities : toset([])

  project = var.project_id
  topic   = google_pubsub_topic.osiris_events.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${each.value}"
}

# Closes CONNECT between the two databases. Run once after apply, and again
# after stg is rebuilt (docs/dev-environment.md). Not part of a deploy.
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

  lifecycle {
    enabled = var.enabled
  }
}

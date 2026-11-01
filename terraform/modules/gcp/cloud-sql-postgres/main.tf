# One Postgres instance, private address only, TLS required. The org policy
# refuses a public address anyway; this module never asks for one.
resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.name
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = true
    user_labels       = var.labels

    deletion_protection_enabled = var.deletion_protection

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      # Encrypted or refused. The clients verify the instance's own CA, which
      # `server_ca_cert` hands them.
      ssl_mode = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = var.backup_retention_days

      backup_retention_settings {
        retained_backups = var.backup_retention_days
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = false
      record_client_address   = false
    }

    dynamic "database_flags" {
      for_each = local.flags
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }
  }
}

locals {
  # What the logs record, so an incident has something to read.
  flags = {
    log_connections            = "on"
    log_disconnections         = "on"
    log_checkpoints            = "on"
    log_lock_waits             = "on"
    log_temp_files             = "0"
    log_min_messages           = "warning"
    log_min_error_statement    = "error"
    log_min_duration_statement = "-1"
  }
}

resource "google_sql_database" "this" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.database_name
}

# The application's user. Terraform creates it with a placeholder and then
# stops being the owner of the password, as the secret module does with
# values: the real one is set by hand with `gcloud sql users set-password` and
# added to the matching secret, and never passes through state.
resource "google_sql_user" "application" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.user_name
  password = var.placeholder_password

  lifecycle {
    ignore_changes = [password]
  }
}

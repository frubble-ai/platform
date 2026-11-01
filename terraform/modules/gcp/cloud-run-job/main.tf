# A one-off task from the application's image: the deploy updates the image
# and executes the job before it rolls the services. As with the service,
# Terraform owns everything but the image.
resource "google_cloud_run_v2_job" "this" {
  project             = var.project_id
  name                = var.name
  location            = var.region
  labels              = var.labels
  deletion_protection = var.deletion_protection

  template {
    labels = var.labels

    template {
      service_account       = var.service_account_email
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
      timeout               = "${var.timeout_seconds}s"
      # A migration that failed is looked at, not retried blind.
      max_retries = 0

      containers {
        image   = var.image
        command = var.command
        args    = var.args

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }

        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = var.secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret
                version = env.value.version
              }
            }
          }
        }
      }

      dynamic "vpc_access" {
        for_each = var.vpc == null ? [] : [var.vpc]
        content {
          egress = "PRIVATE_RANGES_ONLY"
          network_interfaces {
            network    = vpc_access.value.network
            subnetwork = vpc_access.value.subnetwork
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

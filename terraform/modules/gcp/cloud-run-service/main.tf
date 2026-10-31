# One service, one container. Terraform owns everything about it except the
# image: CI deploys a new revision with `gcloud run services update --image`,
# and a later apply keeps whatever image is live.
resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region
  labels   = var.labels

  # Only the load balancer may reach it; the run.app URL answers nothing.
  ingress = var.ingress

  # The org policy forbids allUsers bindings, so public access is expressed by
  # skipping the invoker check. The load balancer is the only caller anyway.
  invoker_iam_disabled = var.invoker_iam_disabled
  deletion_protection  = var.deletion_protection

  template {
    service_account                  = var.service_account_email
    execution_environment            = var.execution_environment
    timeout                          = "${var.timeout_seconds}s"
    max_instance_request_concurrency = var.concurrency
    labels                           = var.labels

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        # Request-based billing: CPU only while a request is in flight.
        cpu_idle          = true
        startup_cpu_boost = var.startup_cpu_boost
      }

      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }

      startup_probe {
        http_get {
          path = var.health_path
          port = var.port
        }
        initial_delay_seconds = 0
        period_seconds        = 2
        timeout_seconds       = 2
        failure_threshold     = 15
      }

      liveness_probe {
        http_get {
          path = var.health_path
          port = var.port
        }
        period_seconds    = 30
        timeout_seconds   = 3
        failure_threshold = 3
      }
    }
  }

  lifecycle {
    # The image is CI's; the client fields are what gcloud stamps on a deploy.
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

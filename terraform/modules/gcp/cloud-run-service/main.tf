# One service, one container. Terraform owns everything about it except the
# image: CI deploys a new revision with `gcloud run services update --image`,
# and a later apply keeps whatever image is live.
resource "google_cloud_run_v2_service" "this" {
  provider = google-beta

  project  = var.project_id
  name     = var.name
  location = var.region
  labels   = var.labels

  # The load balancer is the only way in: the run.app URL does not exist, and
  # ingress admits Google load balancers and nothing from the internet. An
  # external load balancer cannot present an invoker identity (only IAP can,
  # which signs people in, not an API), so the IAM check is off; the org
  # policy forbids an allUsers binding anyway.
  default_uri_disabled = var.default_uri_disabled
  ingress              = var.ingress
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
      image   = var.image
      command = var.command
      args    = var.args

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

    # Direct VPC egress: the instance gets an address in the subnet and only
    # private ranges route through it, so the database is reachable and the
    # internet still goes out the normal way.
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

  lifecycle {
    # The image is CI's; the client fields are what gcloud stamps on a deploy.
    # The service-level scaling block is not set here (scaling is on the
    # template) and the API returns it with zeroed defaults, which would
    # otherwise be an update on every plan.
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
      scaling,
    ]
  }
}

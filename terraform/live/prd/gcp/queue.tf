# ---------- the email queue and the worker that drains it ----------
# The API publishes each email to the topic; Pub/Sub pushes it to the worker
# service, which answers 204 once the email is sent and anything else to have
# it redelivered. Five refusals move a message to the dead-letter topic, and
# the alert below says so.

# Pub/Sub's own identity, which does the dead-lettering. Created with the API
# and named by project number, so it is looked up rather than spelled.
resource "google_project_service_identity" "pubsub" {
  provider = google-beta

  project = var.project_id
  service = "pubsub.googleapis.com"
}

module "worker_service" {
  source = "../../../modules/gcp/cloud-run-service"

  project_id            = var.project_id
  name                  = "${local.name}-worker"
  region                = var.region
  service_account_email = local.setup.worker_service_account
  image                 = var.api_bootstrap_image
  # The image picks what it runs from APP_PROCESS, so the placeholder image
  # starts here too and the service exists before the first deploy. A
  # `command` would make the first revision fail and the service never be
  # created.
  #
  # The worker speaks to its email provider through one adapter chosen by
  # EMAIL_PROVIDER; the key and the sending domain mean the same whichever it
  # is, so swapping providers is a value here and a secret version.
  env = {
    APP_PROCESS     = "worker"
    APP_ENV         = module.shared.environment
    EMAIL_PROVIDER  = var.email_provider
    EMAIL_DOMAIN    = module.shared.sending_domain
    EMAIL_FROM      = "noreply@${module.shared.sending_domain}"
    EMAIL_FROM_NAME = "Frubble"
  }
  secret_env = {
    EMAIL_API_KEY = {
      secret  = module.secrets["email_api_key"].secret_id
      version = var.email_api_key_version
    }
  }
  # Reached by Pub/Sub only: the run.app URL exists, ingress admits same-project
  # Google services and nothing from the internet, and the invoker check holds
  # every caller to the push identity bound below.
  default_uri_disabled = false
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_iam_disabled = false
  max_instances        = 2
  concurrency          = 10
  deletion_protection  = module.shared.environment == "prd"
  labels               = merge(local.labels, { component = "worker" })

  # The secret's first version and the binding on it both exist before the
  # service does: Cloud Run checks a referenced secret when it creates the
  # revision.
  depends_on = [
    module.secrets,
    google_secret_manager_secret_iam_member.worker_reads,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "push_invokes_worker" {
  project  = var.project_id
  location = var.region
  name     = module.worker_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.setup.push_service_account}"
}

module "emails_queue" {
  source = "../../../modules/gcp/pubsub-queue"

  project_id                 = var.project_id
  name                       = "${local.name}-emails"
  push_endpoint              = "${module.worker_service.uri}/push/emails"
  push_service_account_email = local.setup.push_service_account
  publisher_member           = "serviceAccount:${local.setup.api_service_account}"
  service_agent_member       = google_project_service_identity.pubsub.member
  labels                     = merge(local.labels, { component = "queue" })
}

# A message on the dead-letter subscription is an email that never went out:
# someone's sign-up or reset code.
resource "google_monitoring_alert_policy" "emails_dead_lettered" {
  project      = var.project_id
  display_name = "${local.name}: an email could not be delivered"
  combiner     = "OR"
  user_labels  = merge(local.labels, { component = "queue" })

  notification_channels = [module.alerts.notification_channel_id]

  conditions {
    display_name = "messages waiting on the dead-letter subscription"

    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\"",
        "resource.type=\"pubsub_subscription\"",
        "resource.label.subscription_id=\"${module.emails_queue.dead_letter_subscription}\"",
      ])
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MAX"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "Pull the message from `${module.emails_queue.dead_letter_subscription}` to see which email failed, then the worker's logs for why (the email provider's answer is in them). Acknowledge it once handled."
  }

  alert_strategy {
    auto_close = "86400s"
  }
}

# One queue: a topic the API publishes to, a push subscription that hands each
# message to the worker, and a dead-letter topic for what the worker kept
# refusing. Pub/Sub retries a refused push with backoff and gives up after
# `max_delivery_attempts`; what it gives up on waits on the dead-letter
# subscription for a person to look at.
resource "google_pubsub_topic" "this" {
  project = var.project_id
  name    = var.name
  labels  = var.labels
}

resource "google_pubsub_topic" "dead_letter" {
  project = var.project_id
  name    = "${var.name}-dlq"
  labels  = var.labels
}

resource "google_pubsub_subscription" "push" {
  project = var.project_id
  name    = "${var.name}-worker"
  topic   = google_pubsub_topic.this.id
  labels  = var.labels

  # How long the worker has to answer before the push counts as refused.
  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = "${var.retention_days * 24 * 60 * 60}s"

  push_config {
    push_endpoint = var.push_endpoint
    oidc_token {
      service_account_email = var.push_service_account_email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  # Never expires for lack of traffic.
  expiration_policy {
    ttl = ""
  }
}

# Keeps what was dead-lettered until someone reads it.
resource "google_pubsub_subscription" "dead_letter" {
  project = var.project_id
  name    = "${var.name}-dlq"
  topic   = google_pubsub_topic.dead_letter.id
  labels  = var.labels

  message_retention_duration = "${var.retention_days * 24 * 60 * 60}s"

  expiration_policy {
    ttl = ""
  }
}

# Dead-lettering is done by Pub/Sub's own service agent: it needs to publish
# to the dead-letter topic and to acknowledge on the source subscription.
resource "google_pubsub_topic_iam_member" "service_agent_publishes_dead_letters" {
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = var.service_agent_member
}

resource "google_pubsub_subscription_iam_member" "service_agent_forwards" {
  project      = var.project_id
  subscription = google_pubsub_subscription.push.name
  role         = "roles/pubsub.subscriber"
  member       = var.service_agent_member
}

resource "google_pubsub_topic_iam_member" "publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.this.name
  role    = "roles/pubsub.publisher"
  member  = var.publisher_member
}

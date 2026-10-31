# Alert policies for one API behind the load balancer, all to one email
# channel. Each description says what to look at first.

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "${var.name} alerts"
  type         = "email"
  user_labels  = var.labels

  labels = {
    email_address = var.email
  }
}

locals {
  channels = [google_monitoring_notification_channel.email.id]

  lb_requests = join(" AND ", [
    "metric.type=\"loadbalancing.googleapis.com/https/request_count\"",
    "resource.type=\"https_lb_rule\"",
    "resource.label.url_map_name=\"${var.url_map_name}\"",
  ])

  service = join(" AND ", [
    "resource.type=\"cloud_run_revision\"",
    "resource.label.service_name=\"${var.service_name}\"",
  ])
}

resource "google_monitoring_alert_policy" "lb_5xx_ratio" {
  project      = var.project_id
  display_name = "${var.name}: 5xx above ${var.error_ratio * 100}% at the load balancer"
  combiner     = "OR"
  user_labels  = var.labels

  notification_channels = local.channels

  conditions {
    display_name = "5xx / all requests, 5 min"

    condition_threshold {
      filter             = "${local.lb_requests} AND metric.label.response_code_class=\"500\""
      denominator_filter = local.lb_requests
      comparison         = "COMPARISON_GT"
      threshold_value    = var.error_ratio
      duration           = "300s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }

      denominator_aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "Check the Cloud Run request logs for `${var.service_name}` first: a 5xx from the service shows there; one that does not reach it is the balancer's (backend unhealthy, no instance started)."
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "latency_p95" {
  project      = var.project_id
  display_name = "${var.name}: p95 latency above ${var.latency_ms} ms"
  combiner     = "OR"
  user_labels  = var.labels

  notification_channels = local.channels

  conditions {
    display_name = "p95 request latency, 15 min"

    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_latencies\" AND ${local.service}"
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_ms
      duration        = "900s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
        group_by_fields      = ["resource.label.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "Cold starts show as a few slow requests after idle; a sustained rise with instances at the ceiling is saturation, a rise without it is the application."
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "instances_at_max" {
  project      = var.project_id
  display_name = "${var.name}: instances at the ceiling (${var.max_instances})"
  combiner     = "OR"
  user_labels  = var.labels

  notification_channels = local.channels

  conditions {
    display_name = "instance count at max_instances, 10 min"

    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/container/instance_count\" AND ${local.service}"
      comparison      = "COMPARISON_GE"
      threshold_value = var.max_instances
      duration        = "600s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MAX"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "The service cannot add instances. Raise `max_instances` or the per-instance CPU, after checking that the load is legitimate (Cloud Armor logs)."
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

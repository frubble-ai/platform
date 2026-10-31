# One budget for everything on the billing account: the management project
# and both environments. It alerts, it does not stop anything; Google has no
# spending cap, and a stop would be a function that detaches billing, which
# is a separate decision.
#
# Spend is counted before credits. With credits applied, the first months
# would show zero and the budget would say nothing until the credits ran out.

data "google_project" "management" {
  project_id = var.management_project_id
}

locals {
  budget_project_numbers = concat(
    [data.google_project.management.number],
    [for m in module.environment_project : m.number],
  )
}

resource "google_project_service" "management_billingbudgets" {
  project            = var.management_project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "management_monitoring" {
  project            = var.management_project_id
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "budget" {
  project      = var.management_project_id
  display_name = "frubble budget alerts"
  type         = "email"

  labels = {
    email_address = var.budget_alert_email
  }

  depends_on = [google_project_service.management_monitoring]
}

resource "google_billing_budget" "frubble" {
  # The budgets API bills its calls to a quota project; see versions.tf.
  provider = google.quota

  billing_account = var.billing_account
  display_name    = "frubble, every project, per month"

  budget_filter {
    projects               = [for n in local.budget_project_numbers : "projects/${n}"]
    calendar_period        = "MONTH"
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.9
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  # Forecast: the month's spend is on course to pass the budget.
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.budget.id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.management_billingbudgets]
}

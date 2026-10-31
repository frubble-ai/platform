# The WAF on the load balancer: Google's preconfigured rule sets, each of
# which can run in preview (logged, not enforced) until its false positives
# are known, then a per-IP rate limit on everything that got past them.
# Lowest priority number wins and a match ends evaluation, so the throttle
# sits after the WAF rules: its allow would otherwise end the evaluation
# before they ran.
resource "google_compute_security_policy" "this" {
  project     = var.project_id
  name        = var.name
  type        = "CLOUD_ARMOR"
  description = var.description

  # Every request: the policy attaches only to this load balancer, and a
  # match on the Host header would be skipped by sending another one.
  rule {
    action      = "throttle"
    priority    = var.rate_limit.priority
    description = "Per-IP rate limit"

    match {
      expr {
        expression = "true"
      }
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"

      rate_limit_threshold {
        count        = var.rate_limit.count
        interval_sec = var.rate_limit.interval_seconds
      }
    }
  }

  dynamic "rule" {
    for_each = var.waf_rules
    content {
      action      = "deny(403)"
      priority    = rule.value.priority
      preview     = rule.value.preview
      description = "Preconfigured ${rule.key}"

      match {
        expr {
          expression = "evaluatePreconfiguredWaf('${rule.key}', {'sensitivity': ${rule.value.sensitivity}})"
        }
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

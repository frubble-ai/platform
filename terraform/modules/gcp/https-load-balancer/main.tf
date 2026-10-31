# A global external Application Load Balancer in front of Cloud Run services:
# one address, one certificate covering every host, host-based routing to a
# serverless NEG per backend.

resource "google_compute_global_address" "this" {
  project    = var.project_id
  name       = "${var.name}-lb"
  ip_version = "IPV4"
  labels     = var.labels
}

# The certificate validates through a DNS record, so it is issued before the
# hostname points here and the cutover has no window without TLS. The record
# is permanent: renewals reuse it.
resource "google_certificate_manager_dns_authorization" "this" {
  for_each = var.backends

  project  = var.project_id
  name     = "${var.name}-${each.key}"
  location = "global"
  domain   = each.value.host
  labels   = var.labels
}

resource "google_certificate_manager_certificate" "this" {
  project  = var.project_id
  name     = "${var.name}-lb"
  location = "global"
  scope    = "DEFAULT"
  labels   = var.labels

  managed {
    domains            = [for b in var.backends : b.host]
    dns_authorizations = [for a in google_certificate_manager_dns_authorization.this : a.id]
  }
}

resource "google_certificate_manager_certificate_map" "this" {
  project = var.project_id
  name    = "${var.name}-lb"
  labels  = var.labels
}

resource "google_certificate_manager_certificate_map_entry" "this" {
  for_each = var.backends

  project      = var.project_id
  name         = "${var.name}-${each.key}"
  map          = google_certificate_manager_certificate_map.this.name
  certificates = [google_certificate_manager_certificate.this.id]
  hostname     = each.value.host
  labels       = var.labels
}

resource "google_compute_region_network_endpoint_group" "this" {
  for_each = var.backends

  project               = var.project_id
  name                  = "${var.name}-${each.key}"
  region                = each.value.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = each.value.service
  }
}

resource "google_compute_backend_service" "this" {
  for_each = var.backends

  project               = var.project_id
  name                  = "${var.name}-${each.key}"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = var.security_policy

  backend {
    group = google_compute_region_network_endpoint_group.this[each.key].id
  }

  log_config {
    enable      = true
    sample_rate = var.log_sample_rate
  }
}

resource "google_compute_url_map" "this" {
  project         = var.project_id
  name            = "${var.name}-lb"
  default_service = google_compute_backend_service.this[var.default_backend].id

  dynamic "host_rule" {
    for_each = var.backends
    content {
      hosts        = [host_rule.value.host]
      path_matcher = host_rule.key
    }
  }

  dynamic "path_matcher" {
    for_each = var.backends
    content {
      name            = path_matcher.key
      default_service = google_compute_backend_service.this[path_matcher.key].id
    }
  }
}

resource "google_compute_ssl_policy" "this" {
  project         = var.project_id
  name            = "${var.name}-lb"
  profile         = "RESTRICTED"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "this" {
  project         = var.project_id
  name            = "${var.name}-lb"
  url_map         = google_compute_url_map.this.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.this.id}"
  ssl_policy      = google_compute_ssl_policy.this.id
}

# HTTPS only. A port 80 redirect is a second forwarding rule, billed by the hour.
resource "google_compute_global_forwarding_rule" "https" {
  project               = var.project_id
  name                  = "${var.name}-lb-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.this.id
  ip_address            = google_compute_global_address.this.id
  labels                = var.labels
}

resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = "${var.name}-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  project       = var.project_id
  name          = "${var.name}-subnet"
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = var.subnet_cidr

  # Flow logs are what make an IAP session reviewable after the fact. Without
  # them, "who reached the box and when" is unanswerable.
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# The only inbound rule. 35.235.240.0/20 is Google's IAP forwarding range:
# traffic arrives already authenticated by IAM, so port 22 is never exposed to
# the public internet and there is no key on the box to steal.
resource "google_compute_firewall" "iap_ssh" {
  project = var.project_id
  name    = "${var.name}-allow-iap-ssh"
  network = google_compute_network.main.name

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Everything else inbound is dropped explicitly, so a permissive rule added
# elsewhere later cannot quietly open the box.
resource "google_compute_firewall" "deny_all_ingress" {
  project = var.project_id
  name    = "${var.name}-deny-ingress"
  network = google_compute_network.main.name

  direction     = "INGRESS"
  priority      = 65000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.name]

  deny {
    protocol = "all"
  }
}

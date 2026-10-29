data "google_compute_image" "cos" {
  family  = "cos-121-lts"
  project = "cos-cloud"
}

locals {
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml", {
    project_id      = var.project_id
    secret_id       = var.tunnel_token_secret_id
    region          = var.region
    app_port        = var.app_port
    environment     = var.environment
    bootstrap_image = var.bootstrap_image
  })
}

resource "google_compute_instance" "api" {
  project      = var.project_id
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [var.name]
  labels       = var.labels

  boot_disk {
    initialize_params {
      image  = data.google_compute_image.cos.self_link
      size   = var.boot_disk_size_gb
      type   = "pd-standard"
      labels = var.labels
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id

    # Ephemeral, and only for egress — pulling images and dialing out to the
    # Cloudflare edge. Nothing inbound can use it: the firewall denies all
    # ingress except the IAP range. A reserved address would add the one
    # line item on this stack that the free tier does not cover.
    access_config {
      network_tier = "STANDARD"
    }
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    user-data                 = local.cloud_init
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"

    # Logins are an IAM decision, not a file on disk. Blocking project-wide
    # keys closes the path that survives removing someone from the group.
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  # The box is immutable: a cloud-init change replaces it, and CI redeploys
  # the image straight after.
  depends_on = [
    google_secret_manager_secret_iam_member.reads_tunnel_token,
    google_artifact_registry_repository_iam_member.pulls_images,
  ]
}

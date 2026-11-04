# ---------- what the application's deploy identity may touch ----------
# This registry, the three services and the migration job. It cannot create
# another service to run something else.
resource "google_artifact_registry_repository_iam_member" "deploy_pushes" {
  project    = var.project_id
  location   = module.registry.location
  repository = module.registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.setup.deploy_spoke}"

  lifecycle {
    enabled = var.enabled
  }
}

# run.developer on the service lets the deploy create a revision, and also
# change anything else in the template or delete the service; it carries no
# setIamPolicy. Image-only is the deploy script's discipline. Terraform
# ignores only the image, so any other change would show as drift and be
# reverted by the next apply.
resource "google_cloud_run_v2_service_iam_member" "deploy_rolls_out_api" {
  project  = var.project_id
  location = var.region
  name     = module.api_service.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${local.setup.deploy_spoke}"

  lifecycle {
    enabled = var.enabled
  }
}

# The deploy updates the job's image and executes it before rolling the
# service out; run.developer covers both.
resource "google_cloud_run_v2_job_iam_member" "deploy_runs_migrate" {
  project  = var.project_id
  location = var.region
  name     = module.migrate_job.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${local.setup.deploy_spoke}"

  lifecycle {
    enabled = var.enabled
  }
}

resource "google_cloud_run_v2_service_iam_member" "deploy_rolls_out_worker" {
  project  = var.project_id
  location = var.region
  name     = module.worker_service.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${local.setup.deploy_spoke}"

  lifecycle {
    enabled = var.enabled
  }
}

resource "google_cloud_run_v2_service_iam_member" "deploy_rolls_out_app" {
  project  = var.project_id
  location = var.region
  name     = module.app_service.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${local.setup.deploy_spoke}"

  lifecycle {
    enabled = var.enabled
  }
}

locals {
  platform_repo = "${var.github_owner}/${var.platform_repository}"
  backend_repo  = "${var.github_owner}/${var.backend_repository}"

  # Pinning the audience means a token minted for some other Google resource
  # cannot be replayed here, even if it is otherwise valid.
  audience = "https://github.com/${var.github_owner}"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.management_project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "The only way CI authenticates. No service account keys exist."
}

# ---------------------------------------------------------------------------
# Two providers, not one.
#
# GitHub includes the `environment` claim only on jobs that declare an
# environment. A single mapping that referenced it would fail the exchange for
# every plan job, which declares none. Splitting them also makes the entry
# point itself meaningful: a workflow that asks for the apply provider is
# visibly asking for apply.
# ---------------------------------------------------------------------------

resource "google_iam_workload_identity_pool_provider" "plan" {
  project                            = var.management_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-plan"
  display_name                       = "GitHub — plan"
  description                        = "Read-only entry point. Reached from pull requests, so it is treated as running unreviewed code."

  attribute_condition = "assertion.repository == '${local.platform_repo}'"

  attribute_mapping = {
    # The subject is what GCP records as the caller in the audit log, so the
    # run belongs in it: a GenerateAccessToken entry then points at the exact
    # workflow run that caused it. The auth action has no input for this — the
    # mapping here is the only place it can be set.
    #
    # Safe to change: the hub bindings in hubs.tf match on attribute.plan_entry
    # and attribute.apply_entry, never on the subject, so widening this does
    # not alter who may sign in. Capped at 127 bytes, which `sub` plus a run id
    # stays well inside.
    "google.subject" = "assertion.sub + '|run:' + assertion.run_id + '.' + assertion.run_attempt"

    # job_workflow_ref carries the reusable workflow that actually runs the
    # job, as path@ref. workflow_ref would carry the *caller* instead, which
    # any pull request may add — pinning that would pin nothing.
    #
    # The @ref suffix is dropped because on a pull request it is
    # refs/pull/N/merge, which cannot be enumerated in advance. The ref is
    # kept as its own component below, collapsed to a class.
    "attribute.plan_entry" = join("", [
      "assertion.repository + '|' + ",
      "assertion.job_workflow_ref.split('@')[0] + '|' + ",
      "(assertion.ref.startsWith('refs/pull/') ? 'pull-request' : assertion.ref)",
    ])
  }

  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = [local.audience]
  }
}

resource "google_iam_workload_identity_pool_provider" "apply" {
  project                            = var.management_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-apply"
  display_name                       = "GitHub — apply"
  description                        = "Write entry point. Only reachable from a job running inside a GitHub environment."

  attribute_condition = "assertion.repository in ['${local.platform_repo}', '${local.backend_repo}']"

  attribute_mapping = {
    # Carries the run, as above: the audit entry names the run that caused it.
    "google.subject" = "assertion.sub + '|run:' + assertion.run_id + '.' + assertion.run_attempt"

    # The exact ref is kept here, unlike in the plan entry: every apply runs
    # from a branch, so it can be stated, and stating it is what stops an
    # apply workflow from being run off a fork or a tag.
    "attribute.apply_entry" = join("", [
      "assertion.repository + '|' + ",
      "assertion.job_workflow_ref.split('@')[0] + '|' + ",
      "assertion.environment + '|' + ",
      "assertion.ref",
    ])
  }

  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = [local.audience]
  }
}

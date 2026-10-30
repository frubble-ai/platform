# Deny beats allow everywhere, including a role someone grants by hand later
# in the console. These are the guarantees that survive a mistake, as opposed
# to the role lists above, which only describe the intent.

locals {
  deny_parent = urlencode("cloudresourcemanager.googleapis.com/projects/${var.project_id}")

}

# Two identities that must never read a secret value, for different reasons.
#
# Plan runs on pull-request code that nobody has reviewed: if it can read a
# value, a two-line change to the plan step prints it to a public log.
#
# The tunnel-token writer only ever writes. secretVersionAdder already omits
# the read, but the writer is reached by a deploy job, and a role widened later
# — by hand, in the console, under pressure — would hand that job the value it
# just wrote. Deny makes the one-way street a guarantee rather than a property
# of the role list.
resource "google_iam_deny_policy" "no_secret_values" {
  parent = local.deny_parent
  name   = "frubble-no-secret-values"
  # 63 characters at most — the API's limit. The longer wording this had
  # failed every apply with a 400, so this policy never existed until it was
  # shortened, and nothing but the apply output said so.
  display_name = "Plan and token writer may see a secret exists, never its value"

  rules {
    deny_rule {
      denied_principals = [
        module.plan_spoke.principal,
        module.tunnel_token_writer.principal,
        # Plans this project's _setup root from pull requests, holding a
        # narrow read role (org/gcp/_setup/setup_pipeline.tf) with no secret
        # access. Denying it here is defence in depth.
        local.org.setup_plan_principal,
      ]
      denied_permissions = ["secretmanager.googleapis.com/versions.access"]
    }
  }
}

resource "google_iam_deny_policy" "apply_cannot_escalate" {
  parent       = local.deny_parent
  name         = "frubble-apply-cannot-escalate"
  display_name = "Apply cannot raise its own rights or erase the record"

  # There is no rule here forbidding the apply identity from editing the
  # spokes. Deny conditions accept only tag-matching functions — endsWith and
  # extract are both rejected — so the restriction cannot be written as a
  # deny. It lives in the allow instead: serviceAccountAdmin reaches only the
  # instance account, so the spokes are out of reach to begin with.

  # The state bucket is the record of what exists. An apply that can delete it
  # can make the infrastructure unaccountable while leaving it running and
  # billing.
  rules {
    deny_rule {
      denied_principals = [module.apply_spoke.principal, module.plan_spoke.principal]
      denied_permissions = [
        "storage.googleapis.com/buckets.delete",
        "storage.googleapis.com/buckets.update",
        "storage.googleapis.com/buckets.setIamPolicy",
      ]
    }
  }

  # Destroying the key destroys every state file it ever encrypted, with no
  # recovery by any means once the deletion delay passes.
  rules {
    deny_rule {
      denied_principals = [module.apply_spoke.principal, module.plan_spoke.principal]
      denied_permissions = [
        "cloudkms.googleapis.com/cryptoKeyVersions.destroy",
        "cloudkms.googleapis.com/cryptoKeys.update",
        "cloudkms.googleapis.com/cryptoKeys.setIamPolicy",
      ]
    }
  }
}

# Secrets

Two kinds, told apart in the workload root's `secrets.tf`. A value Terraform can generate
(the database password, the auth secret) is generated during the apply by an ephemeral
`random_password` and written through write-only attributes, to Secret Manager and, for the
password, to the database user in the same run. Neither value is ever in state or in a plan;
what state records is `secrets_version`, the number that pins them. Bumping it in a pull
request rotates both: the apply generates new values, writes them, and the services pick
them up on their next revision. A value that comes from outside (the email provider's API
key) gets a container and a placeholder from Terraform, and the root that holds the value
writes the real version the same write-only way (`stg/mailgun` and `dev/mailgun` for their
environments, `org/mailgun/_setup` for prd, email.md). Each
service reads only the secrets bound to its identity, per secret.

`secrets_version` does not rotate osiris's encryption key. That key wraps every
tenant's data key; a new value makes the stored tokens unreadable. It has its own
pin, `osiris_encryption_key_version`, bumped only in a change that re-wraps the
data keys. The other generated osiris values (its database password, API key and
admin key) move with `secrets_version`, same as the application's.

The osiris API key is generated here for the serve process. The application's API
reads it later; nothing in the application is bound to it yet. The admin key is
the operator key. Read it as the administrator (the plan identity is denied every
secret value):

```sh
PROJECT="$(gh variable get GCP_PROJECT_DEV)"  # or GCP_PROJECT_STG
gcloud secrets versions access latest --secret "frubble_dev_osiris_admin-key" --project "$PROJECT"
```

The id is `frubble_<env>_osiris_admin-key` (the secret module joins the path with
underscores). `frubble_<env>_osiris_api-key` is the client key. `frubble_<env>_database_grants-password`
is only for the database grant job.

Composio's project API key has no root that writes it: after the apply, add the value by hand,
then roll the API so its next revision reads it.

```sh
ENV=stg  # or dev, or prd
read -rs KEY && [ -n "$KEY" ] && printf '%s' "$KEY" |
  gcloud secrets versions add "frubble_${ENV}_composio_api-key" --data-file=- --project "frubble-${ENV}"
```

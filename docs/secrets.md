# Secrets

Two kinds, told apart in the workload root's `secrets.tf`. A value Terraform can generate
(the database password, the auth secret) is generated during the apply by an ephemeral
`random_password` and written through write-only attributes, to Secret Manager and, for the
password, to the database user in the same run. Neither value is ever in state or in a plan;
what state records is `secrets_version`, the number that pins them. Bumping it in a pull
request rotates both: the apply generates new values, writes them, and the services pick
them up on their next revision. A value that comes from outside (the email provider's API
key) gets a container and a placeholder from Terraform, and the root that holds the value
writes the real version the same write-only way (`org/mailgun/_setup`, or `dev/mailgun`
for dev, email.md). Each
service reads only the secrets bound to its identity, per secret.

Composio's project API key has no root that writes it: after the apply, add the value by hand,
then roll the API so its next revision reads it.

```sh
ENV=stg  # or dev, or prd
read -rs KEY && [ -n "$KEY" ] && printf '%s' "$KEY" |
  gcloud secrets versions add "frubble_${ENV}_composio_api-key" --data-file=- --project "frubble-${ENV}"
```

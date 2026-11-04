# Human access

`gcloud auth login`, no keys. The developer group is read-only and cannot read secret
values. One named administrator has full access. Nobody gets a shell.

Everyone else is listed, with their access, in the `ORG_MEMBERS_ACCESS` secret of the
`organization-member-access` environment, keyed by a short handle. The environment also
holds its own `POSTHOG_APPLY_API_KEY` and `POSTHOG_OWNER_EMAIL`, the account that key belongs
to, which never gets a level.

```json
{ "alex": { "email": "alex@example.com", "gcp": { "dev": ["administration"], "stg": ["administration"], "prd": ["read_only"] }, "posthog": "member" } }
```

GCP profiles are `read_only`, `administration` and `logs`, granted to `gcp.account` when the
Google account's primary address differs from `email`; PostHog levels are `member` and
`admin`, once the person has accepted an invite. After editing it, run
`organization-member-access-cd`.

# Layout

```
terraform/
  live/
    org/gcp/_setup            projects, state bucket, identity pool, hubs
    org/cloudflare/_setup     zone-wide settings and the plan token
    org/cloudflare            DNS shared by every environment
    org/posthog               the PostHog project
    org/mailgun/_setup        the sending keys the workers use, written into each environment's secret
    stg/shared                what every stg root agrees on: its name, zone and hostnames; no state
    stg/gcp/_setup            stg state bucket, spokes, deny policies
    stg/gcp                   the stg API service, web app service, load balancer, WAF, alerts, registry, network, database, secrets, migration job, email queue, worker service, and the trust rules of its deploy identities
    stg/cloudflare            the stg hostnames' DNS (the API's and the web app's A records and certificate authorizations), and the sending domain's SPF, DKIM and DMARC
    stg/mailgun               the stg sending domain at Mailgun
    prd/…                     the same, not yet applied
  modules/                    shared code, no state. gcp/cloud-run-service, gcp/https-load-balancer, gcp/cloud-armor and gcp/alerts are the API's stack; gcp/network, gcp/cloud-sql-postgres and gcp/cloud-run-job its database and migration; gcp/pubsub-queue the email queue; naming the rule the shared/ modules derive their names with
```

One root per scope and provider, one state each. In a root, `main.tf` holds only its wiring:
the shared values module and root-wide locals. Every other resource and module sits in a
sibling file named for what it is (`api.tf`, `load_balancer.tf`, `domain.tf`). A root with no
wiring has no `main.tf`.

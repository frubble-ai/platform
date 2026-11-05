# Crossing roots

A value one root produces and another needs is written by the producer, during its apply,
as one JSON object in the management bucket under the consumer's own prefix, named by its
content: `<env>/cloudflare/handoff/gcp-<hash>.json`, `<env>/cloudflare/handoff/mailgun-<hash>.json`.
A new content is a new object, written before the old one is deleted, so there is always a
handoff to read, and the provider never has to plan an update to content it learns only during
the apply. The consumer lists that prefix and reads each producer's object; one that does not
exist yet, before its producer's first apply, feeds nothing, and the resources it feeds do not
exist yet either, while two of one producer's fail the plan until that producer's next apply has
deleted the old. The producer's apply identity may write its own objects and nothing else under
that prefix, which holds the consumer's state; the consumer's identities read the prefix
already, since it is theirs. The workflow runs the consumer after its producers, so one run carries a value from
the root that makes it to the root that publishes it.

To roll back to fixed handoff names, keep the prefix grants until the producers have moved:
apply the reverted GCP and Mailgun roots first, so they write `gcp.json` and `mailgun.json` and
delete their hashed objects, and only then apply the setup roots that narrow the grants to the
exact names. Narrowing first leaves each producer unable to read its own hashed object, and its
plan fails.

No repository variable ever carries a Terraform output to another root. A variable is set
by a person, so it drifts from the output it copies, it is read at the start of a run so it
lags the apply that changed it, and nothing reviews it. The variables that remain are CI's
own configuration: which identities to sign in as, which projects and buckets exist, which
features are switched on. The exception is `_setup` outputs copied once at bootstrap, before
any pipeline exists to carry them.

The GCP workload root hands the Cloudflare root two values. `certificate_dns_authorizations`,
one CNAME per hostname (the API's, `api.`, the web app's, `app.`, and osiris's, `osiris.`): the Cloudflare root
publishes each, DNS-only, and Certificate Manager issues that hostname's certificate against it;
the records are permanent, since renewals reuse them. A certificate per hostname, so adding one
never replaces the certificate another is serving with. `load_balancer_ip`: the hostnames' A
records, DNS-only too, since proxied every client would arrive from Cloudflare's addresses and
Cloud Armor's per-IP limit would be one budget for all of them. Both arrive in one object, with
`published_hosts`: the hostnames whose A records the Cloudflare root publishes, for the API, the app and
osiris alike. A hostname joins once it serves TLS, its certificate issued and its certificate-map
entry active, and stays: the GCP root keeps the previous handoff's list, so a renewal that shows a
certificate as provisioning again never takes a record down. A new hostname's certificate issues
against its authorization, which the same run publishes, so its A record follows on the next
`stg-cd` run after the certificate is issued (Actions → stg-cd → Run workflow, a few minutes
later). The handoff also keeps `certificate_dns_authorization`, the API's alone,
which it carried before the map. The Cloud Run services and the migration job start on a
placeholder image; the application's deploys replace it and Terraform ignores the image from
then on.

A handoff object changes the way a schema does: a field is added, and the consumer reads it
only when present, so the consumer's plan on the pull request, which still sees the object
the last apply wrote, plans nothing for what the field will bring. A field goes once no
consumer reads it.

The database is a Cloud SQL Postgres instance with a private address only, in the
environment's VPC, reached by the service and the job through direct VPC egress and TLS
against the instance's own CA, which the root passes to them as `DB_CA_PEM`. No person
reaches the database: there is no public address and no bastion; the migration job and the
application are its only clients.

Email leaves through a Pub/Sub topic the API publishes to. A push subscription posts each
message to the worker, a second Cloud Run service on the same image started as the worker,
reachable by Pub/Sub's identity and nothing else: its run.app URL exists, its ingress admits
same-project Google services only, and its invoker check holds every caller to the push
identity. The worker answers 204 once the email is sent; anything else is redelivered with
backoff, and after five refusals the message moves to the dead-letter topic, whose backlog
raises the one alert this stack adds. The worker holds the email provider's key and no
database access.

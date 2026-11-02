# The environment's shared values: its name, zone and hostnames (README,
# "Shared values").
module "shared" {
  source = "../shared"
}

locals {
  hostname = module.shared.api_hostname
  # The hostnames whose A record this root publishes, from the GCP root's handoff:
  # each joins once it serves TLS and stays. A handoff written before the
  # list existed carries none, and the API's record was live by then.
  published_hosts = local.gcp == null ? [] : try(local.gcp.published_hosts, ["api"])
}

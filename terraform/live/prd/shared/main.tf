# What every prd root agrees on, said once. The roots cannot read each
# other's state, so a value they share lives here, with no provider and no
# state of its own, and each root calls this module (README, "Shared values").
# Nothing here is secret.
module "naming" {
  source = "../../../modules/naming"

  environment = "prd"
  zone        = "frubble.ai"
}

output "environment" {
  value = module.naming.environment
}

output "zone" {
  value = module.naming.zone
}

output "name" {
  value = module.naming.name
}

output "api_hostname" {
  value = module.naming.api_hostname
}

output "sending_domain" {
  value = module.naming.sending_domain
}

output "labels" {
  value = module.naming.labels
}

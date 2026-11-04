# The environment's shared values: its name, zone and hostnames
# (docs/shared-values.md).
module "shared" {
  source = "../shared"
}

locals {
  setup  = data.terraform_remote_state.setup.outputs
  name   = module.shared.name
  labels = module.shared.labels
}

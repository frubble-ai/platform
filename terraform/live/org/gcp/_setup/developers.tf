# Human access is granted here, on both environment projects, because who may
# look and who may act are single facts about the organization rather than
# something each environment decides for itself.
module "human_access" {
  for_each = var.environment_projects
  source   = "../../../../modules/gcp/developer-access"

  project_id    = each.value
  group         = var.developer_group
  administrator = var.administrator

  depends_on = [module.environment_project]
}

# This module was `developer_access` until the roles became read-only and
# administration. Terraform keys state by address, so without this it reads the
# rename as "one module gone, another arrived" and plans a destroy beside a
# create. The deny policy's name is fixed in the module, so whichever order it
# chose, the apply would hit "already exists" half way through.
#
# Moving the module block covers every instance of its for_each.
moved {
  from = module.developer_access
  to   = module.human_access
}

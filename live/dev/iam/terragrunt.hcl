include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules/iam"
}

inputs = {
  cloud_id    = local.env_vars.locals.cloud_id
  folder_id   = local.env_vars.locals.folder_id
  bucket_name = "dev-oll"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules/infra"

  after_hook "generate_report" {
    commands     = ["apply"]
    execute      = ["bash", "${get_parent_terragrunt_dir()}/scripts/generate-report.sh"]
    run_on_error = false
  }
}

dependency "iam" {
  config_path = "../iam"

  # Фиктивные значения для этапа plan, пока iam еще не применен
  mock_outputs = {
    service_account_id = "aje00000000000000000"
    static_access_key  = "YCAJEmockaccesskey1234567890"
    secret_key         = "mock-secret-key-value-1234567890"
    bucket_name        = "dev-oll-tfstate-mock"
  }
}

inputs = {
  cloud_id       = local.env_vars.locals.cloud_id
  folder_id      = local.env_vars.locals.folder_id
  zone           = local.env_vars.locals.zone
  ssh_user       = local.env_vars.locals.ssh_user
  ssh_public_key = local.env_vars.locals.ssh_public_key
  vm_image_id    = local.env_vars.locals.vm_image_id
}

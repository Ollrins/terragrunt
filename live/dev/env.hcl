locals {
  # Читаем корневой конфигурационный файл
  root_config = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  environment = "dev"

  # Берем значения из блока inputs корневого файла
  cloud_id  = local.root_config.inputs.cloud_id
  folder_id = local.root_config.inputs.folder_id
  zone      = local.root_config.inputs.zone

  ssh_user       = "Ollrins"
  ssh_public_key = "/home/Ollrins/key.pub"
  vm_image_id    = "fd828j3n8sa03unu5arm"
}

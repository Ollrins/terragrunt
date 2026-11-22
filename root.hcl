# ==========================================
# Корневой root.hcl
# ==========================================

locals {
  cloud_id  = get_env("YC_CLOUD_ID", "b1....")
  folder_id = get_env("YC_FOLDER_ID", "b1....")
  zone      = get_env("YC_ZONE", "ru-central1-d")
  root_dir  = "/home/Ollrins"
}

# ---------- Remote state (S3) ----------
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket         = "dev-oll"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "ru-central1"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

# ---------- Provider ----------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROVIDER_EOF
terraform {
  required_version = "~> 1.14.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.193.0"
    }
  }
}

provider "yandex" {
  zone                     = "${local.zone}"
  service_account_key_file = "${local.root_dir}/key.json"
  cloud_id                 = "${local.cloud_id}"
  folder_id                = "${local.folder_id}"
}
PROVIDER_EOF
}

# Передаем переменные во все дочерние модули автоматически
inputs = {
  cloud_id  = local.cloud_id
  folder_id = local.folder_id
  zone      = local.zone
}

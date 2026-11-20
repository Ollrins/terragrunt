resource "yandex_iam_service_account" "terraform_sa" {
  name        = "terragrunt-sa"
  description = "Service account for Terragrunt infrastructure management"
}

resource "yandex_resourcemanager_folder_iam_member" "terraform_roles" {
  for_each = toset([
    "editor",
    "storage.admin",
    "container-registry.admin",
    "kms.admin"
  ])

  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "terraform_sa_key" {
  service_account_id = yandex_iam_service_account.terraform_sa.id
  description        = "Static access key for Terragrunt"
}

#resource "yandex_storage_bucket" "tfstate" {
#  bucket        = var.bucket_name
#  force_destroy = false
#}

#resource "yandex_storage_bucket_grant" "tfstate_grant" {
#  bucket = yandex_storage_bucket.tfstate.bucket

#  grant {
#    id          = yandex_iam_service_account.terraform_sa.id
#    type        = "CanonicalUser"
#    permissions = ["FULL_CONTROL"]
#  }
#}

output "service_account_id" {
  value = yandex_iam_service_account.terraform_sa.id
}

output "static_access_key" {
  value     = yandex_iam_service_account_static_access_key.terraform_sa_key.access_key
  sensitive = true
}

output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.terraform_sa_key.secret_key
  sensitive = true
}

# Бакет управляется вручную и существует вечно. 
# Просто отдаем его точное имя, чтобы модуль infra мог на него сослаться.
output "bucket_name" {
  value = "dev-oll"
}

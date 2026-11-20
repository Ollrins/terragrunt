# terragrunt
Создание кластера k8s с использованием terragrunt
# 🚀 Kubernetes Cluster Deployment (Yandex Cloud)

Этот репозиторий содержит инфраструктуру как код (IaC) для развертывания высокодоступного кластера Kubernetes в Yandex Cloud с использованием **Terragrunt**, **Terraform**, **Ansible** и **Docker**.

## 🏗 Архитектура и стек технологий

- **Cloud Provider:** Yandex Cloud (Compute, VPC, IAM, Container Registry, Object Storage)
- **IaC Orchestration:** Terragrunt + Terraform (OpenTofu compatible)
- **Configuration Management:** Ansible (Rocky Linux 8/9)
- **Container Orchestration:** Kubernetes v1.29 (kubeadm, containerd, Flannel CNI)
- **Ingress & Monitoring:** NGINX Ingress Controller, Prometheus Operator + Grafana
- **CI/CD & Registry:** Yandex Container Registry (YCR), Docker Buildx

## 📂 Структура проекта

```text
.
├── ansible/
│   ├── inventory.ini           # Генерируется автоматически скриптом deploy
│   └── playbook-rocky.yml      # Плейбук для настройки K8s, Ingress и Grafana
├── app/
│   ├── Dockerfile              # Образ тестового приложения
│   ├── index.html              # Статический контент приложения
│   └── app-deployment.yaml     # Манифесты K8s (Deployment, Service, Ingress)
├── live/dev/
│   ├── env.hcl                 # Переменные окружения dev
│   ├── iam/                    # Модуль IAM (Service Account, Keys, S3 Bucket)
│   └── infra/                  # Модуль инфраструктуры (VPC, VMs, Registry)
├── modules/
│   ├── iam/                    # Terraform модуль IAM
│   └── infra/                  # Terraform модуль вычислительных ресурсов
├── scripts/
│   └── generate-report.sh      # (Опционально) Скрипт генерации отчета
├── deploy-all.sh               # 🚀 Главный скрипт автоматического развертывания
├── root.hcl                    # Корневая конфигурация Terragrunt (Provider, Backend)
└── README.md                   # Этот файл


## 🛠 Предварительные требования

Перед запуском убедитесь, что у вас установлены:

- `terraform` (или `opentofu`) >= 1.14.0
- `terragrunt` >= 0.50.0
- `ansible` >= 2.15
- `docker` (с настроенным `buildx`)
- `kubectl`
- `jq`

Для полного развертывания инфраструктуры, настройки кластера и деплоя приложения выполните одну команду:

```bash
./deploy-all.sh
```
Скрипт автоматически выполнит следующие шаги:
1. Создаст IAM-ресурсы и базовую инфраструктуру через Terragrunt.
2. Дождется полной загрузки и доступности виртуальных машин по SSH.
3. Сгенерирует динамический Ansible inventory.
4. Настроит Kubernetes, установит Flannel (CNI), NGINX Ingress и стек мониторинга (Grafana/Prometheus) через Ansible.
5. Соберет Docker-образ (строго для архитектуры `linux/amd64` для совместимости с YCR) и задеплоит его в кластер.
6. Сгенерирует и опубликует HTML-отчет о статусе развертывания с корректной кодировкой и favicon.

---

## 🌐 Доступ к сервисам

После успешного выполнения скрипта все сервисы будут доступны по внешнему IP-адресу Master-ноды (`<MASTER_IP>`):

| Сервис | URL | Описание |
| :--- | :--- | :--- |
| **Тестовое приложение** | `http://<MASTER_IP>/app` | Простое веб-приложение, развернутое в K8s |
| **Grafana Dashboard** | `http://<MASTER_IP>/` | Мониторинг кластера (kube-prometheus stack) |
| **Отчет Terragrunt** | `http://<MASTER_IP>:8080/terragrunt-report/` | HTML-страница со статусом и ссылками на развертывание |

> 🔑 **Доступ к Grafana по умолчанию:**
> - **Логин:** `admin`
> - **Пароль:** `admin`

---

## 🧹 Очистка инфраструктуры (Destroy)

Чтобы удалить все созданные ресурсы и избежать списания средств в Яндекс.Облаке, выполните:

```bash
cd live/dev
terragrunt destroy --all --non-interactive
```

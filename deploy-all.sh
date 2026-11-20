#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Terragrunt: полное развертывание"
echo "=========================================="

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

SSH_KEY="/home/Ollrins/key"
SSH_USER="Ollrins"
LIVE_DIR="$BASE_DIR/live/dev"

# ==========================================
# ШАГ 1: IAM + Infra через Terragrunt
# ==========================================
echo -e "\n[1/6] Применение IAM и инфраструктуры через Terragrunt..."
cd "$LIVE_DIR"
terragrunt run init --all --non-interactive
terragrunt run apply --all --non-interactive

cd "$LIVE_DIR/infra"
# Извлекаем чистый IP без http:// и слэшей
MASTER_IP_RAW=$(terragrunt output -json master_ips | jq -r '.[0]')
MASTER_IP=$(echo "$MASTER_IP_RAW" | sed -e 's|http://||' -e 's|/||g')
WORKER_IPS=$(terragrunt output -json worker_ips | jq -r '.[]')
REGISTRY_ID=$(terragrunt output -raw registry_id)

echo "✅ Мастер-нода: $MASTER_IP"
echo "✅ ID реестра: $REGISTRY_ID"

# ==========================================
# ШАГ 2: Ожидание SSH
# ==========================================
echo -e "\n[2/6] Ожидание загрузки всех виртуальных машин..."
ALL_IPS="$MASTER_IP $WORKER_IPS"
for ip in $ALL_IPS; do
    for i in {1..60}; do
        if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SSH_USER@$ip" "echo 'SSH ready'" 2>/dev/null; then
            echo "✅ Узел $ip доступен!"
            break
        fi
        sleep 5
    done
done

# ==========================================
# ШАГ 3: Ansible Inventory
# ==========================================
echo -e "\n[3/6] Генерация Ansible inventory..."
cd "$BASE_DIR/ansible"
cat > inventory.ini << '__INI_END__'
[masters]
master ansible_host=PLACEHOLDER_MASTER ansible_user=Ollrins
[workers]
__INI_END__
sed -i "s/PLACEHOLDER_MASTER/$MASTER_IP/" inventory.ini
count=1
for ip in $WORKER_IPS; do
    echo "worker$count ansible_host=$ip ansible_user=Ollrins" >> inventory.ini
    count=$((count + 1))
done
cat >> inventory.ini << '__INI_END__'
[k8s_cluster:children]
masters
workers
[all:vars]
ansible_ssh_private_key_file = /home/Ollrins/key
ansible_ssh_common_args = '-o StrictHostKeyChecking=no'
ansible_python_interpreter = /usr/bin/python3
__INI_END__

# ==========================================
# ШАГ 4: Ansible Playbook
# ==========================================
echo -e "\n[4/6] Установка Kubernetes, мониторинга и nginx для отчёта..."
ansible-playbook -i inventory.ini playbook-rocky.yml -v

# ==========================================
# ШАГ 5: Настройка локального kubectl
# ==========================================
echo -e "\n[5/6] Настройка локального kubectl..."
mkdir -p ~/.kube
ssh -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" \
  "mkdir -p /home/$SSH_USER/.kube && sudo cp /etc/kubernetes/admin.conf /home/$SSH_USER/.kube/config && sudo chown $SSH_USER:$SSH_USER /home/$SSH_USER/.kube/config && chmod 600 /home/$SSH_USER/.kube/config"
scp -q -i "$SSH_KEY" "$SSH_USER@$MASTER_IP:/home/$SSH_USER/.kube/config" ~/.kube/config
sed -i "s|server: https://.*:6443|server: https://$MASTER_IP:6443|" ~/.kube/config
sed -i '/certificate-authority-data/d' ~/.kube/config
sed -i "/server: https:\/\/$MASTER_IP:6443/a\    insecure-skip-tls-verify: true" ~/.kube/config
kubectl get nodes

# ==========================================
# ШАГ 6: Сборка и деплой приложения (ИСПРАВЛЕННАЯ СБОРКА)
# ==========================================
echo -e "\n[6/6] Сборка и деплой приложения..."
cd "$BASE_DIR/app"
KEY_FILE="/home/Ollrins/key.json"
IMAGE_URI="cr.yandex/$REGISTRY_ID/app:v1.0.0"

# Очищаем креды docker от старых записей Yandex Cloud
python3 -c "
import json, os
cfg = os.path.expanduser('~/.docker/config.json')
if os.path.exists(cfg):
    try:
        with open(cfg, 'r') as f: data = json.load(f)
        if 'credHelpers' in data and 'cr.yandex' in data['credHelpers']:
            del data['credHelpers']['cr.yandex']
            if not data['credHelpers']: del data['credHelpers']
        with open(cfg, 'w') as f: json.dump(data, f, indent=4)
    except Exception:
        pass
"

cat "$KEY_FILE" | docker login --username json_key --password-stdin cr.yandex

# Создаем или используем правильный buildx builder
docker buildx create --name ycr-builder --use 2>/dev/null || docker buildx use ycr-builder

# СБОРКА С КЛЮЧЕВЫМИ ФЛАГАМИ ДЛЯ YCR (отключаем аттестации, чтобы не ломать манифест)
echo "🔨 Сборка и отправка образа в Yandex Container Registry..."
docker buildx build --platform linux/amd64 --push --provenance=false --sbom=false -t "$IMAGE_URI" .

# Создаем секрет для Kubernetes
kubectl create secret docker-registry yc-registry-secret \
  --docker-server=cr.yandex \
  --docker-username=json_key \
  --docker-password="$(cat "$KEY_FILE")" \
  --docker-email=not@used.com \
  --dry-run=client -o yaml | kubectl apply -f -

# Применяем манифест
sed "s|REGISTRY_ID|$REGISTRY_ID|g" app-deployment.yaml > app-deployment.rendered.yaml
kubectl apply -f app-deployment.rendered.yaml
kubectl rollout status deployment/app -n default --timeout=120s

# ==========================================
# ШАГ 7: Генерация и публикация отчёта Terragrunt
# ==========================================
echo -e "\n[7/7] Генерация отчёта о развертывании..."

# Шаблон отчёта с favicon-ракетой и динамической датой
cat << 'REPORT_EOF' > /tmp/terragrunt-report-template.html
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terragrunt Deployment Report</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🚀</text></svg>">
    <meta property="og:title" content="Terragrunt Deployment Report">
    <meta property="og:description" content="Kubernetes cluster successfully deployed via Terragrunt">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 40px; background: #f4f7f6; color: #333; }
        .container { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 8px 16px rgba(0,0,0,0.1); max-width: 800px; margin: 0 auto; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .success { color: #27ae60; font-weight: bold; font-size: 1.1em; margin: 8px 0; }
        .info-box { margin-top: 30px; padding: 20px; background: #e8f4f8; border-left: 5px solid #3498db; border-radius: 4px; }
        .info-box p { margin: 10px 0; }
        .info-box a { color: #2980b9; text-decoration: none; font-weight: bold; }
        .info-box a:hover { text-decoration: underline; }
        .footer { margin-top: 30px; font-size: 0.9em; color: #7f8c8d; text-align: center; }
        .timestamp { font-family: 'Courier New', monospace; color: #95a5a6; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 Инфраструктура успешно развернута!</h1>
        <p class="success">✅ Kubernetes Cluster: Ready (1 Master, 2 Workers)</p>
        <p class="success">✅ Application: Deployed & Running</p>
        <p class="success">✅ Monitoring (Grafana/Prometheus): Installed</p>
        <p class="success">✅ Nginx Report Server: Active on port 8080</p>
        <div class="info-box">
            <p><strong>🖥 Master Node:</strong> MASTER_IP_PLACEHOLDER</p>
            <p><strong>🌐 Приложение:</strong> <a href="http://MASTER_IP_PLACEHOLDER/app" target="_blank">http://MASTER_IP_PLACEHOLDER/app</a></p>
            <p><strong>📊 Grafana:</strong> <a href="http://MASTER_IP_PLACEHOLDER/" target="_blank">http://MASTER_IP_PLACEHOLDER/</a></p>
            <p><strong>📄 Отчёт:</strong> <a href="http://MASTER_IP_PLACEHOLDER:8080/terragrunt-report/" target="_blank">http://MASTER_IP_PLACEHOLDER:8080/terragrunt-report/</a></p>
        </div>
        <p class="footer">
            Сгенерировано автоматически скриптом развертывания Terragrunt<br>
            <span class="timestamp" id="timestamp"></span>
        </p>
    </div>
    <script>
        document.getElementById('timestamp').textContent = 
            'Дата: ' + new Date().toLocaleString('ru-RU', { 
                timeZone: 'Europe/Moscow', dateStyle: 'full', timeStyle: 'medium'
            });
    </script>
</body>
</html>
REPORT_EOF

# Подставляем реальный IP
sed "s/MASTER_IP_PLACEHOLDER/${MASTER_IP}/g" /tmp/terragrunt-report-template.html > /tmp/terragrunt-report.html

# Загружаем на сервер
scp -q -i "$SSH_KEY" -o StrictHostKeyChecking=no /tmp/terragrunt-report.html "$SSH_USER@$MASTER_IP:/tmp/report.html"

# Настраиваем права, SELinux и перезагружаем Nginx
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$MASTER_IP" " \
  sudo mv /tmp/report.html /usr/share/nginx/html/terragrunt-report/index.html && \
  sudo chown nginx:nginx /usr/share/nginx/html/terragrunt-report/index.html && \
  sudo chmod 644 /usr/share/nginx/html/terragrunt-report/index.html && \
  sudo restorecon -v /usr/share/nginx/html/terragrunt-report/index.html && \
  sudo systemctl reload nginx \
"

echo ""
echo "=========================================="
echo "🎉 РАЗВЕРТЫВАНИЕ ПОЛНОСТЬЮ ЗАВЕРШЕНО!"
echo "=========================================="
echo "📄 Отчёт Terragrunt:   http://${MASTER_IP}:8080/terragrunt-report/"
echo "=========================================="

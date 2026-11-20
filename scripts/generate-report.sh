#!/bin/bash
set -e

MASTER_IP=$(terraform output -json master_ips | jq -r '.[0]')
REGISTRY_ID=$(terraform output -raw registry_id)
WORKER_IPS=$(terraform output -json worker_ips | jq -r '.[]' | tr '\n' ' ')
NETWORK_ID=$(terraform output -raw network_id)
SUBNET_ID=$(terraform output -raw subnet_id)
SG_ID=$(terraform output -raw security_group_id)

TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
SSH_KEY="/home/Ollrins/key"
SSH_USER="Ollrins"

TMP_HTML="/tmp/terragrunt-report-$$.html"

cat > "$TMP_HTML" << HTML_EOF
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Infrastructure provisioned by Terragrunt</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
            color: #e0e0e0;
            margin: 0;
            padding: 40px 20px;
            min-height: 100vh;
        }
        .container { max-width: 900px; margin: 0 auto; }
        h1 {
            font-size: 2.5em;
            background: linear-gradient(90deg, #00d2ff, #3a7bd5);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        .subtitle { color: #888; margin-bottom: 40px; font-size: 1.1em; }
        .card {
            background: rgba(255,255,255,0.05);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 12px;
            padding: 25px;
            margin-bottom: 20px;
        }
        .card h2 { color: #00d2ff; margin-top: 0; font-size: 1.3em; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
        .item { background: rgba(0,0,0,0.3); padding: 12px 16px; border-radius: 8px; }
        .label { color: #888; font-size: 0.85em; text-transform: uppercase; letter-spacing: 1px; }
        .value { font-family: 'Courier New', monospace; font-size: 1.1em; color: #fff; margin-top: 4px; word-break: break-all; }
        .badge {
            display: inline-block;
            background: #4ec9b0;
            color: #000;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: bold;
        }
        .footer { text-align: center; color: #555; margin-top: 40px; font-size: 0.9em; }
        ul { margin: 10px 0; padding-left: 20px; }
        li { margin: 8px 0; }
        code { background: rgba(0,0,0,0.4); padding: 2px 8px; border-radius: 4px; color: #00d2ff; }
    </style>
</head>
<body>
<div class="container">
    <h1>⚡ Infrastructure provisioned by Terragrunt</h1>
    <p class="subtitle">Эта страница сгенерирована автоматически после <code>terragrunt apply</code></p>

    <div class="card">
        <h2>📦 Что было создано</h2>
        <ul>
            <li><span class="badge">IAM</span> Сервисный аккаунт <code>terragrunt-sa</code> с ролями и статическим ключом</li>
            <li><span class="badge">IAM</span> S3-бакет <code>dev-oll</code> для хранения Terraform state</li>
            <li><span class="badge">Infra</span> VPC-сеть <code>terragrunt-network</code> и подсеть в зоне <code>ru-central1-d</code></li>
            <li><span class="badge">Infra</span> Security Group <code>terragrunt-sg</code> с правилами для K8s и отчёта</li>
            <li><span class="badge">Infra</span> Master-нода (<code>terragrunt-master-1</code>)</li>
            <li><span class="badge">Infra</span> Worker-ноды (<code>terragrunt-worker-*</code>)</li>
            <li><span class="badge">Infra</span> Container Registry <code>terragrunt-registry</code></li>
        </ul>
    </div>

    <div class="card">
        <h2>🖥️ Параметры инфраструктуры</h2>
        <div class="grid">
            <div class="item">
                <div class="label">Master IP</div>
                <div class="value">${MASTER_IP}</div>
            </div>
            <div class="item">
                <div class="label">Registry ID</div>
                <div class="value">${REGISTRY_ID}</div>
            </div>
            <div class="item">
                <div class="label">Worker IPs</div>
                <div class="value">${WORKER_IPS:-N/A}</div>
            </div>
            <div class="item">
                <div class="label">Generated at</div>
                <div class="value">${TIMESTAMP}</div>
            </div>
            <div class="item">
                <div class="label">Network ID</div>
                <div class="value">${NETWORK_ID}</div>
            </div>
            <div class="item">
                <div class="label">Subnet ID</div>
                <div class="value">${SUBNET_ID}</div>
            </div>
            <div class="item">
                <div class="label">Security Group ID</div>
                <div class="value">${SG_ID}</div>
            </div>
        </div>
    </div>

    <div class="card">
        <h2>🔧 Как это сделано</h2>
        <p>Модуль <code>infra</code> в Terragrunt содержит <code>after_hook</code>, который после успешного <code>apply</code> вызывает скрипт генерации отчёта. Скрипт читает <code>terraform output</code>, создаёт этот HTML и копирует его на мастер-ноду по <code>scp</code>. Nginx на мастере отдаёт файл на порту 8080.</p>
    </div>

    <div class="footer">
        Terragrunt + Terraform + Yandex Cloud · Автоматическая генерация отчёта
    </div>
</div>
</body>
</html>
HTML_EOF

echo "📄 Отчёт сгенерирован: $TMP_HTML"
echo "📤 Копируем на мастер-ноду ($MASTER_IP)..."

scp -q -i "$SSH_KEY" -o StrictHostKeyChecking=no "$TMP_HTML" "$SSH_USER@$MASTER_IP:/tmp/terragrunt-report.html"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$MASTER_IP" \
  "sudo mkdir -p /usr/share/nginx/html/terragrunt-report && \
   sudo mv /tmp/terragrunt-report.html /usr/share/nginx/html/terragrunt-report/index.html && \
   sudo chmod 644 /usr/share/nginx/html/terragrunt-report/index.html"

echo "✅ Отчёт доступен: http://$MASTER_IP:8080/"

rm -f "$TMP_HTML"

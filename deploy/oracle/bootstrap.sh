#!/usr/bin/env bash
set -euo pipefail

# Oracle Always Free VM bootstrap for CPU-only OBLITERATUS hosting.
# Expected target: Ubuntu on OCI Ampere A1.

REPO_URL="${REPO_URL:-https://github.com/gsfit1996/obliterateee.git}"
REPO_REF="${REPO_REF:-main}"
APP_DIR="${APP_DIR:-/opt/obliteratus}"
APP_PORT="${APP_PORT:-8080}"
HOST_BIND="${HOST_BIND:-127.0.0.1}"
ENABLE_NGINX="${ENABLE_NGINX:-1}"
APP_USER="${APP_USER:-}"

if [[ -z "${APP_USER}" ]]; then
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    APP_USER="${SUDO_USER}"
  else
    APP_USER="$(id -un)"
  fi
fi

APP_HOME="$(getent passwd "${APP_USER}" | cut -d: -f6)"
if [[ -z "${APP_HOME}" ]]; then
  echo "Could not resolve home directory for APP_USER=${APP_USER}" >&2
  exit 1
fi

APP_GROUP="$(id -gn "${APP_USER}")"

echo "Bootstrapping OBLITERATUS for Oracle CPU host"
echo "  user: ${APP_USER}"
echo "  app dir: ${APP_DIR}"
echo "  repo: ${REPO_URL} @ ${REPO_REF}"
echo "  bind: ${HOST_BIND}:${APP_PORT}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  ffmpeg \
  git \
  libsndfile1 \
  nginx \
  python3 \
  python3-pip \
  python3-venv
rm -rf /var/lib/apt/lists/*

mkdir -p "${APP_DIR}"
chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"

if [[ ! -d "${APP_DIR}/.git" ]]; then
  sudo -u "${APP_USER}" git clone "${REPO_URL}" "${APP_DIR}"
fi

sudo -u "${APP_USER}" git -C "${APP_DIR}" fetch --all --tags --prune
sudo -u "${APP_USER}" git -C "${APP_DIR}" checkout "${REPO_REF}"
sudo -u "${APP_USER}" git -C "${APP_DIR}" pull --ff-only origin "${REPO_REF}" || true

sudo -u "${APP_USER}" mkdir -p \
  "${APP_DIR}/.hf_home" \
  "${APP_DIR}/logs" \
  "${APP_DIR}/run"

if [[ ! -x "${APP_DIR}/.venv/bin/python" ]]; then
  sudo -u "${APP_USER}" python3 -m venv "${APP_DIR}/.venv"
fi

sudo -u "${APP_USER}" "${APP_DIR}/.venv/bin/python" -m pip install --upgrade pip setuptools wheel
sudo -u "${APP_USER}" "${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.cpu.txt"
sudo -u "${APP_USER}" "${APP_DIR}/.venv/bin/pip" install --no-deps -e "${APP_DIR}"

cat > /etc/systemd/system/obliteratus.service <<EOF
[Unit]
Description=OBLITERATUS local UI + OpenRouter-compatible API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_DIR}
Environment=PYTHONUTF8=1
Environment=PYTHONIOENCODING=utf-8
Environment=OBLITERATUS_API_DEFAULT_MODEL=Qwen/Qwen2.5-0.5B-Instruct
Environment=HF_HOME=${APP_DIR}/.hf_home
Environment=TRANSFORMERS_CACHE=${APP_DIR}/.hf_home/hub
Environment=HF_HUB_CACHE=${APP_DIR}/.hf_home/hub
ExecStart=${APP_DIR}/.venv/bin/python ${APP_DIR}/app.py --host ${HOST_BIND} --port ${APP_PORT}
Restart=always
RestartSec=5
TimeoutStartSec=180
StandardOutput=append:${APP_DIR}/logs/obliteratus.log
StandardError=append:${APP_DIR}/logs/obliteratus.err.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now obliteratus.service

if [[ "${ENABLE_NGINX}" == "1" ]]; then
  cat > /etc/nginx/sites-available/obliteratus <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    client_max_body_size 100m;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_connect_timeout 60s;

    location / {
        proxy_pass http://${HOST_BIND}:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

  rm -f /etc/nginx/sites-enabled/default
  ln -sf /etc/nginx/sites-available/obliteratus /etc/nginx/sites-enabled/obliteratus
  nginx -t
  systemctl enable --now nginx
  systemctl reload nginx
fi

echo
echo "OBLITERATUS bootstrap complete."
echo "Health checks:"
echo "  sudo systemctl status obliteratus --no-pager"
echo "  curl http://${HOST_BIND}:${APP_PORT}/v1/models"
if [[ "${ENABLE_NGINX}" == "1" ]]; then
  echo "  curl http://127.0.0.1/"
fi

#!/usr/bin/env bash
set -euo pipefail

exec > >(tee /var/log/obliteratus-startup.log | logger -t obliteratus-startup -s 2>/dev/console) 2>&1

meta() {
  curl -fsH "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/$1"
}

REPO_URL="$(meta instance/attributes/repo-url || true)"
REPO_REF="$(meta instance/attributes/repo-ref || true)"
APP_DIR="$(meta instance/attributes/app-dir || true)"
APP_PORT="$(meta instance/attributes/app-port || true)"
APP_USER="$(meta instance/attributes/app-user || true)"
HOST_BIND="$(meta instance/attributes/host-bind || true)"
ENABLE_NGINX="$(meta instance/attributes/enable-nginx || true)"
INSTALL_OPS_AGENT="$(meta instance/attributes/install-ops-agent || true)"

export REPO_URL="${REPO_URL:-https://github.com/gsfit1996/obliterateee.git}"
export REPO_REF="${REPO_REF:-main}"
export APP_DIR="${APP_DIR:-/opt/obliteratus}"
export APP_PORT="${APP_PORT:-8080}"
export APP_USER="${APP_USER:-obliteratus}"
export HOST_BIND="${HOST_BIND:-127.0.0.1}"
export ENABLE_NGINX="${ENABLE_NGINX:-1}"
export INSTALL_OPS_AGENT="${INSTALL_OPS_AGENT:-0}"

if [[ -f "/etc/systemd/system/obliteratus.service" && -x "${APP_DIR}/.venv/bin/python" ]]; then
  systemctl daemon-reload
  systemctl enable --now obliteratus
  if [[ "${ENABLE_NGINX}" == "1" ]]; then
    systemctl enable --now nginx
  fi
  exit 0
fi

if [[ -x "${APP_DIR}/deploy/gcp/bootstrap.sh" ]]; then
  bash "${APP_DIR}/deploy/gcp/bootstrap.sh"
  exit 0
fi

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${TMP_DIR}/repo"
bash "${TMP_DIR}/repo/deploy/gcp/bootstrap.sh"

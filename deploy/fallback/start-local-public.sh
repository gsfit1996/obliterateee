#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8080}"
HOST="${HOST:-localhost}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

resolve_python() {
  if [[ -x "${REPO_ROOT}/.venv314/bin/python" ]]; then
    echo "${REPO_ROOT}/.venv314/bin/python"
    return
  fi
  if [[ -x "${REPO_ROOT}/.venv/bin/python" ]]; then
    echo "${REPO_ROOT}/.venv/bin/python"
    return
  fi
  command -v python3 || command -v python
}

wait_url() {
  local url="$1"
  local deadline=$((SECONDS + 120))
  while (( SECONDS < deadline )); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for ${url}" >&2
  return 1
}

port_is_open() {
  local host="$1"
  local port="$2"
  python3 - "$host" "$port" <<'PY' >/dev/null 2>&1 || python - "$host" "$port" <<'PY' >/dev/null 2>&1
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.settimeout(1.0)
    raise SystemExit(0 if sock.connect_ex((host, port)) == 0 else 1)
PY
}

ensure_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then
    return 0
  fi
  echo "cloudflared is not installed." >&2
  echo "Install it first: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/" >&2
  return 1
}

cd "${REPO_ROOT}"

if ! port_is_open "${HOST}" "${PORT}"; then
  PYTHON_EXE="$(resolve_python)"
  echo "Starting local OBLITERATUS server on http://${HOST}:${PORT} ..."
  nohup "${PYTHON_EXE}" app.py --host "${HOST}" --port "${PORT}" >/tmp/obliteratus-fallback.log 2>&1 &
  echo "Local server PID: $!"
  wait_url "http://${HOST}:${PORT}/"
else
  echo "Reusing existing listener on port ${PORT}."
fi

ensure_cloudflared
echo "Opening Cloudflare Quick Tunnel for http://${HOST}:${PORT} ..."
echo "This is development-only and not suitable for production."
exec cloudflared tunnel --url "http://${HOST}:${PORT}"

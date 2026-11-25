#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(podman compose)
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v podman-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(podman-compose)
else
  echo "ERROR: Neither 'podman compose' nor 'docker compose' found on PATH."
  exit 1
fi

echo "==> [1/3] Building and starting LfSt Fachverfahren Demo Stack (${COMPOSE_CMD[*]})..."
"${COMPOSE_CMD[@]}" -f docker-compose.demo.yml up -d --build

echo "==> [2/3] Waiting for WildFly application server readiness (:9990/health/ready)..."
MAX_ATTEMPTS=40
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:9990/health/ready" || true)
  if [[ "${STATUS}" == "200" ]]; then
    echo "    WildFly is UP and READY (attempt ${i}/${MAX_ATTEMPTS})."
    break
  fi
  if [[ "${i}" -eq "${MAX_ATTEMPTS}" ]]; then
    echo "ERROR: WildFly did not become ready within timeout."
    "${COMPOSE_CMD[@]}" -f docker-compose.demo.yml logs steuer-pruefdienst
    exit 1
  fi
  sleep 2
done

echo "==> [3/3] Running automated readiness and functional smoke checks..."
./ops/scripts/verify-readiness.sh "http://127.0.0.1:8080" "http://127.0.0.1:9990"

cat <<EOF

=========================================================================
LfSt Fachverfahren Steuer (ID 244) Demo Stack is READY
=========================================================================
1. Fachverfahren Info API : http://127.0.0.1:8080/api/info
2. Steuernummer Pruefung  : http://127.0.0.1:8080/api/validate?steuernummer=91234567890
3. WildFly Readiness Probe: http://127.0.0.1:9990/health/ready
4. Prometheus Alerts      : http://127.0.0.1:9090/alerts
5. Grafana Live Dashboard : http://127.0.0.1:3000  (Auto-Login active / admin : ***ENTFERNT***)
=========================================================================
EOF

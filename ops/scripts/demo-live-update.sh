#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

NEW_TARIFF_YEAR="${1:-2027}"
NEW_APP_VERSION="${2:-1.1.0}"

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

echo "==> Rolling out configuration update (APP_TARIFF_YEAR=${NEW_TARIFF_YEAR}, APP_VERSION=${NEW_APP_VERSION})..."
APP_TARIFF_YEAR="${NEW_TARIFF_YEAR}" APP_VERSION="${NEW_APP_VERSION}" \
  "${COMPOSE_CMD[@]}" -f docker-compose.demo.yml up -d --no-deps steuer-pruefdienst

echo "==> Waiting for WildFly readiness probe (:9990/health/ready)..."
for ((i=1; i<=30; i++)); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:9990/health/ready" || true)
  if [[ "${STATUS}" == "200" ]]; then
    break
  fi
  sleep 1
done

./ops/scripts/verify-readiness.sh "http://127.0.0.1:8080" "http://127.0.0.1:9990" "${NEW_TARIFF_YEAR}"

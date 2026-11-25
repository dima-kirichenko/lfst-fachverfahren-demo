#!/usr/bin/env bash
set -euo pipefail

APP_BASE_URL="${1:-http://127.0.0.1:8080}"
MGMT_BASE_URL="${2:-http://127.0.0.1:9990}"
EXPECTED_TARIFF_YEAR="${3:-}"

echo "[1/3] Checking WildFly MicroProfile Readiness endpoint (${MGMT_BASE_URL}/health/ready)..."
READY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${MGMT_BASE_URL}/health/ready")
if [[ "${READY_STATUS}" != "200" ]]; then
  echo "ERROR: Readiness probe failed with HTTP ${READY_STATUS}"
  exit 1
fi

echo "[2/3] Checking Fachverfahren service info endpoint (${APP_BASE_URL}/api/info)..."
INFO_JSON=$(curl -sf "${APP_BASE_URL}/api/info")
echo "Response: ${INFO_JSON}"

if [[ -n "${EXPECTED_TARIFF_YEAR}" ]]; then
  if ! grep -q "\"tariffYear\":\"${EXPECTED_TARIFF_YEAR}\"" <<< "${INFO_JSON}"; then
    echo "ERROR: Expected tariffYear ${EXPECTED_TARIFF_YEAR} not found in response!"
    exit 1
  fi
fi

echo "[3/3] Checking functional tax ID validation endpoint (${APP_BASE_URL}/api/validate)..."
VALIDATE_JSON=$(curl -sf "${APP_BASE_URL}/api/validate?steuernummer=91234567890")
if ! grep -q "\"validFormat\":true" <<< "${VALIDATE_JSON}"; then
  echo "ERROR: Functional validation check failed: ${VALIDATE_JSON}"
  exit 1
fi

echo "SUCCESS: Fachverfahren steuer-pruefdienst is healthy and ready."

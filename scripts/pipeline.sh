
#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-citybike:v1}"
TEST_PORT=4174
PROD_PORT=4173

echo "=================================="
echo "CityBike Five-Environment Pipeline"
echo "Image: ${IMAGE_NAME}"
echo "=================================="

# ==================================
# STAGING
# ==================================

echo ""
echo "========== STAGING =========="

docker rm -f citybike-staging 2>/dev/null || true

docker run -d \
  --name citybike-staging \
  -p "${TEST_PORT}:4173" \
  -e APP_ENV=staging \
  "${IMAGE_NAME}"

echo "Waiting for Staging to become healthy..."

for i in $(seq 1 20); do
  if curl -sf "http://localhost:${TEST_PORT}/health" > /dev/null; then
    break
  fi
  sleep 1
done

TARGET_URL="http://localhost:${TEST_PORT}" bash scripts/test-staging.sh

echo "STAGING GATE PASSED"

docker rm -f citybike-staging


# ==================================
# UAT
# ==================================

echo ""
echo "========== UAT =========="

docker rm -f citybike-uat 2>/dev/null || true

docker run -d \
  --name citybike-uat \
  -p "${TEST_PORT}:4173" \
  -e APP_ENV=uat \
  "${IMAGE_NAME}"

echo "Waiting for UAT to become healthy..."

for i in $(seq 1 20); do
  if curl -sf "http://localhost:${TEST_PORT}/health" > /dev/null; then
    break
  fi
  sleep 1
done

TARGET_URL="http://localhost:${TEST_PORT}" bash scripts/test-uat.sh

echo "UAT GATE PASSED"

docker rm -f citybike-uat


# ==================================
# OAT
# ==================================

echo ""
echo "========== OAT =========="

docker rm -f citybike-oat 2>/dev/null || true

docker run -d \
  --name citybike-oat \
  -p "${TEST_PORT}:4173" \
  -e APP_ENV=oat \
  "${IMAGE_NAME}"

echo "Waiting for OAT to become healthy..."

for i in $(seq 1 20); do
  if curl -sf "http://localhost:${TEST_PORT}/health" > /dev/null; then
    break
  fi
  sleep 1
done

TARGET_URL="http://localhost:${TEST_PORT}" bash scripts/test-oat.sh

echo "OAT GATE PASSED"

docker rm -f citybike-oat


# ==================================
# PREPROD
# ==================================

echo ""
echo "========== PREPROD =========="

docker rm -f citybike-preprod 2>/dev/null || true

docker run -d \
  --name citybike-preprod \
  -p "${TEST_PORT}:4173" \
  -e APP_ENV=preprod \
  -e PROD_API_KEY="${PROD_API_KEY:?Set PROD_API_KEY before running the pipeline}" \
  "${IMAGE_NAME}"

echo "Waiting for Preprod to become healthy..."

for i in $(seq 1 20); do
  if curl -sf "http://localhost:${TEST_PORT}/health" > /dev/null; then
    break
  fi
  sleep 1
done

IMAGE_NAME="${IMAGE_NAME}" \
TARGET_URL="http://localhost:${TEST_PORT}" \
bash scripts/test-preprod.sh

echo "PREPROD GATE PASSED"

docker rm -f citybike-preprod
# ==================================
# PRODUCTION
# ==================================

echo ""
echo "========== PRODUCTION =========="

docker rm -f citybike-prod 2>/dev/null || true

docker run -d \
  --name citybike-prod \
  -p "${PROD_PORT}:4173" \
  -e APP_ENV=production \
  -e PROD_API_KEY="${PROD_API_KEY:?Set PROD_API_KEY before running the pipeline}" \
  "${IMAGE_NAME}"

echo "Waiting for Production to become healthy..."

for i in $(seq 1 20); do
  if curl -sf "http://localhost:${PROD_PORT}/health" > /dev/null; then
    break
  fi
  sleep 1
done

TARGET_URL="http://localhost:${PROD_PORT}" bash scripts/test-prod.sh

echo "PRODUCTION GATE PASSED"
echo "ALL FIVE ENVIRONMENTS PASSED!"
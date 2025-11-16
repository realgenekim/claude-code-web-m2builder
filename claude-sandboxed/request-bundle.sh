#!/usr/bin/env bash
# Submit M2 bundle request via HTTP gateway

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Load credentials
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Error: .env file not found"
  echo "   Create .env from .env.example and add your credentials"
  echo "   cp .env.example .env"
  exit 1
fi

source "$ENV_FILE"

# Validate credentials
if [ -z "${GCS_GATEWAY_URL:-}" ] || [ -z "${GCS_GATEWAY_USER:-}" ] || [ -z "${GCS_GATEWAY_PASS:-}" ]; then
  echo "❌ Error: Missing credentials in .env"
  echo "   Required: GCS_GATEWAY_URL, GCS_GATEWAY_USER, GCS_GATEWAY_PASS"
  exit 1
fi

# Parse arguments
BUNDLE_ID="${1:-}"

if [ -z "$BUNDLE_ID" ]; then
  echo "Usage: $0 BUNDLE_ID"
  echo ""
  echo "Available bundles:"
  echo "  clojure-minimal         - Clojure core only (5 MB)"
  echo "  web-stack              - Ring + Reitit + Muuntaja (17 MB)"
  echo "  gcs-client             - Google Cloud Storage (47 MB)"
  echo "  reddit-scraper-server2 - Full server2 stack (100 MB)"
  echo ""
  echo "Example:"
  echo "  $0 gcs-client"
  exit 1
fi

# Generate unique IDs
TIMESTAMP=$(date +%s)
SESSION_ID="${SESSION_ID_PREFIX:-claude-web}-${TIMESTAMP}"
REQUEST_ID="req-${TIMESTAMP}"

# Create request EDN
REQUEST_CONTENT=$(cat <<EOF
{:schema-version \"1.0.0\"
 :timestamp \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
 :from \"${SESSION_ID}\"
 :session-id \"${SESSION_ID}\"
 :message-id \"${REQUEST_ID}\"
 :type :request
 :payload {:bundle-id \"${BUNDLE_ID}\"}}
EOF
)

# Escape for JSON
REQUEST_CONTENT_JSON=$(echo "$REQUEST_CONTENT" | sed 's/"/\\"/g' | tr -d '\n')

# Build JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "path": "requests/${SESSION_ID}/${REQUEST_ID}.edn",
  "content": "${REQUEST_CONTENT_JSON}",
  "content_type": "application/edn"
}
EOF
)

# Submit request
echo "Submitting request to M2 Bundler..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -u "${GCS_GATEWAY_USER}:${GCS_GATEWAY_PASS}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  "${GCS_GATEWAY_URL}/upload")

# Parse response
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" -eq 201 ] || [ "$HTTP_CODE" -eq 200 ]; then
  echo "✅ Request submitted successfully!"
  echo ""
  echo "Request ID:  ${REQUEST_ID}"
  echo "Session ID:  ${SESSION_ID}"
  echo "Bundle:      ${BUNDLE_ID}"
  echo ""
  echo "Check status with:"
  echo "  ./check-status.sh ${SESSION_ID} ${REQUEST_ID}"
  echo ""
  echo "Expected wait time:"
  case "$BUNDLE_ID" in
    clojure-minimal|web-stack)
      echo "  ~30-60 seconds"
      ;;
    gcs-client)
      echo "  ~60 seconds"
      ;;
    reddit-scraper-server2)
      echo "  ~60-120 seconds"
      ;;
    *)
      echo "  ~60-120 seconds (depends on bundle size)"
      ;;
  esac
else
  echo "❌ Request failed (HTTP $HTTP_CODE)"
  echo "$BODY" | grep -o '"error"[^}]*' || echo "$BODY"
  exit 1
fi

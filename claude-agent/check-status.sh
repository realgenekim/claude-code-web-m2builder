#!/usr/bin/env bash
# Check status of M2 bundle request

set -euo pipefail

# Parse arguments
SESSION_ID="${1:-}"
REQUEST_ID="${2:-}"

if [ -z "$SESSION_ID" ] || [ -z "$REQUEST_ID" ]; then
  echo "Usage: $0 SESSION_ID REQUEST_ID"
  echo ""
  echo "Example:"
  echo "  $0 claude-web-1731700000 req-1731700000"
  exit 1
fi

# Response URL (public-read, so no auth needed)
RESPONSE_URL="https://storage.googleapis.com/gene-m2-bundler-mailbox/responses/${SESSION_ID}/${REQUEST_ID}.edn"

# Try to download response
RESPONSE_FILE="/tmp/response-${REQUEST_ID}.edn"

echo "Checking for response..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" "$RESPONSE_URL")

if [ "$HTTP_CODE" -eq 200 ]; then
  echo "✅ Response received!"
  echo ""
  cat "$RESPONSE_FILE"
  echo ""

  # Extract bundle URL if present
  if grep -q ':bundle-url' "$RESPONSE_FILE"; then
    BUNDLE_URL=$(grep ':bundle-url' "$RESPONSE_FILE" | sed 's/.*:bundle-url "\([^"]*\)".*/\1/')
    echo "──────────────────────────────────────"
    echo "Download command:"
    echo "  ./download-bundle.sh ${BUNDLE_URL}"
    echo "──────────────────────────────────────"
  fi

  # Check if error
  if grep -q ':status :error' "$RESPONSE_FILE"; then
    echo "❌ Build failed - see error details above"
    exit 1
  fi

elif [ "$HTTP_CODE" -eq 404 ]; then
  echo "⏳ Still processing... (check again in 30s)"
  echo ""
  echo "Poll automatically:"
  echo "  while ! $0 $SESSION_ID $REQUEST_ID | grep -q '✅'; do sleep 30; done"
else
  echo "❌ Unexpected response (HTTP $HTTP_CODE)"
  echo "   Response URL: $RESPONSE_URL"
  exit 1
fi

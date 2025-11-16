#!/bin/bash
# Rotate M2 Gateway password
# Usage: ./rotate-gateway-password.sh [new-password]
#
# If no password provided, generates a random one.
# Updates both local secrets file and Cloud Run environment.

set -e

SECRETS_FILE=~/src.local/secrets/m2-gateway-password.txt
SERVICE_NAME=m2-gateway
REGION=us-central1
GATEWAY_URL=https://m2-gateway-1018897188794.us-central1.run.app

# Get new password
if [ -n "$1" ]; then
    NEW_PASS="$1"
else
    echo "Generating random password..."
    NEW_PASS=$(openssl rand -hex 28)
fi

# Get old password for testing
if [ -f "$SECRETS_FILE" ]; then
    OLD_PASS=$(cat "$SECRETS_FILE")
    echo "Old password: ${OLD_PASS:0:10}..."
else
    OLD_PASS=""
    echo "No existing password file found"
fi

echo "New password: ${NEW_PASS:0:10}..."
echo ""

# Step 1: Update Cloud Run
echo "1. Updating Cloud Run environment variable..."
gcloud run services update $SERVICE_NAME \
    --region $REGION \
    --set-env-vars="GATEWAY_PASS=$NEW_PASS" \
    --quiet

echo "   ✅ Cloud Run updated"

# Step 2: Update local secrets file
echo "2. Updating local secrets file..."
echo "$NEW_PASS" > "$SECRETS_FILE"
chmod 600 "$SECRETS_FILE"
echo "   ✅ Saved to $SECRETS_FILE"

# Step 3: Verify old password fails (if we had one)
if [ -n "$OLD_PASS" ]; then
    echo "3. Verifying old password is rejected..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$GATEWAY_URL/request" \
        -u "claude:$OLD_PASS" \
        -H "Content-Type: application/json" \
        -d '{"bundle_id": "rotation-test"}')

    if [ "$HTTP_CODE" = "401" ]; then
        echo "   ✅ Old password rejected (HTTP 401)"
    else
        echo "   ⚠️  WARNING: Old password got HTTP $HTTP_CODE (expected 401)"
    fi
fi

# Step 4: Verify new password works
echo "4. Verifying new password works..."
RESPONSE=$(curl -s -X POST "$GATEWAY_URL/request" \
    -u "claude:$NEW_PASS" \
    -H "Content-Type: application/json" \
    -d '{"bundle_id": "rotation-test-verify"}')

if echo "$RESPONSE" | grep -q '"status": "submitted"'; then
    echo "   ✅ New password works!"
    echo "   Response: $(echo "$RESPONSE" | python3 -c 'import sys, json; d=json.load(sys.stdin); print(f"request_id={d[\"request_id\"]}")')"
else
    echo "   ❌ ERROR: New password failed!"
    echo "   Response: $RESPONSE"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "✅ Password rotation complete!"
echo ""
echo "New password stored in: $SECRETS_FILE"
echo ""
echo "To use locally:"
echo "  make gateway-run"
echo ""
echo "To share with sandboxed agents:"
echo "  cat $SECRETS_FILE"
echo "═══════════════════════════════════════════════════"

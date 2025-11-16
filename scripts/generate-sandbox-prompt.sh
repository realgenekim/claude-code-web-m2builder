#!/bin/bash
# Generate sandbox agent prompt with embedded password
# Creates a file that is gitignored so secrets are never committed

set -e

SECRETS_FILE=~/src.local/secrets/m2-gateway-password.txt
OUTPUT_FILE=./claude-sandboxed/SANDBOX_PROMPT_WITH_SECRET.md

if [ ! -f "$SECRETS_FILE" ]; then
    echo "ERROR: Password file not found at $SECRETS_FILE"
    exit 1
fi

PASSWORD=$(cat "$SECRETS_FILE")

cat > "$OUTPUT_FILE" << EOF
# M2 Bundle Setup - Copy/Paste for Sandbox Agent

**Generated**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

**DO NOT COMMIT THIS FILE** - Contains credentials

---

## Quick Setup (Copy this entire block)

\`\`\`bash
# 1. Download and extract COMPLETE bundle (71 MB, 252 JARs)
mkdir -p ~/.m2-cache && cd ~/.m2-cache && \\
curl -L -o bundle.tar.gz \\
  https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz && \\
tar -xzf bundle.tar.gz && rm bundle.tar.gz && \\
echo "✅ Bundle extracted"

# 2. Configure Clojure to use bundle
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p \$CLJ_CONFIG
echo '{:mvn/local-repo "'\$HOME'/.m2-cache"}' > \$CLJ_CONFIG/deps.edn
echo "✅ Clojure configured"

# 3. Verify
find ~/.m2-cache -name "*.jar" | wc -l
# Should show: 252
\`\`\`

---

## Gateway Access (For Request/Response System)

\`\`\`bash
export GATEWAY_URL="https://m2-gateway-1018897188794.us-central1.run.app"
export GATEWAY_AUTH="claude:${PASSWORD}"

# Test connection
curl -s \$GATEWAY_URL/ | python3 -m json.tool | head -10

# Submit bundle request
curl -s -X POST \$GATEWAY_URL/request \\
  -u \$GATEWAY_AUTH \\
  -H "Content-Type: application/json" \\
  -d '{"bundle_id": "reddit-scraper-server2"}'

# Check status (replace SESSION_ID and REQUEST_ID)
# curl -s \$GATEWAY_URL/status/SESSION_ID/REQUEST_ID -u \$GATEWAY_AUTH
\`\`\`

---

## Verification Commands

\`\`\`bash
# Count JARs
find ~/.m2-cache -name "*.jar" | wc -l
# Expected: 252

# Check Clojure versions available
ls ~/.m2-cache/org/clojure/clojure/
# Expected: 1.11.1 1.11.3 1.12.0 1.12.3

# Verify Clojure sees bundle
clojure -Spath | grep '.m2-cache' | head -3
\`\`\`
EOF

echo "✅ Generated: $OUTPUT_FILE"
echo "   Password embedded (first 10 chars): ${PASSWORD:0:10}..."
echo ""
echo "Copy instructions from that file to share with sandbox agent."

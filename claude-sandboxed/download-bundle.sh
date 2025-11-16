#!/usr/bin/env bash
# Download and extract M2 bundle

set -euo pipefail

# Parse arguments
BUNDLE_URL="${1:-}"

if [ -z "$BUNDLE_URL" ]; then
  echo "Usage: $0 BUNDLE_URL"
  echo ""
  echo "Example:"
  echo "  $0 https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/gcs-client-1731700000.tar.gz"
  exit 1
fi

# Configuration
DEST_DIR="${M2_DEST:-${HOME}/.m2-cache}"
TMP_DIR="${TMP_DIR:-/tmp}"

# Extract filename
BUNDLE_FILE="${TMP_DIR}/$(basename "$BUNDLE_URL")"

echo "Downloading bundle..."
echo "  From: $BUNDLE_URL"
echo "  To:   $BUNDLE_FILE"

# Download
if ! curl -f -L -o "$BUNDLE_FILE" --progress-bar "$BUNDLE_URL"; then
  echo "❌ Download failed"
  exit 1
fi

echo "✅ Downloaded: $(du -h "$BUNDLE_FILE" | cut -f1)"
echo ""

# Create destination
mkdir -p "$DEST_DIR"

echo "Extracting bundle..."
echo "  To: $DEST_DIR"

# Extract (handle both .tar.gz and .tar.zst)
if [[ "$BUNDLE_FILE" == *.tar.gz ]]; then
  tar -xzf "$BUNDLE_FILE" -C "$DEST_DIR"
elif [[ "$BUNDLE_FILE" == *.tar.zst ]]; then
  if command -v zstd &> /dev/null; then
    zstd -d "$BUNDLE_FILE" | tar -x -C "$DEST_DIR"
  else
    echo "❌ zstd not installed (needed for .tar.zst files)"
    echo "   Install with: brew install zstd"
    exit 1
  fi
else
  echo "❌ Unknown archive format: $BUNDLE_FILE"
  exit 1
fi

echo "✅ Bundle extracted to: $DEST_DIR"
echo ""

# Count JARs
JAR_COUNT=$(find "$DEST_DIR" -name '*.jar' | wc -l | tr -d ' ')
DISK_USAGE=$(du -sh "$DEST_DIR" | cut -f1)

echo "Statistics:"
echo "  JARs:      $JAR_COUNT"
echo "  Disk used: $DISK_USAGE"
echo ""

# Usage instructions
echo "──────────────────────────────────────"
echo "Configure Clojure to use this cache:"
echo ""
echo "Option 1 - Environment variable (recommended):"
echo "  export CLJ_CONFIG=/tmp/.clj-config"
echo "  mkdir -p \$CLJ_CONFIG"
echo "  echo '{:mvn/local-repo \"${DEST_DIR}\"}' > \$CLJ_CONFIG/deps.edn"
echo ""
echo "Option 2 - Per-command:"
echo "  clojure -Sdeps '{:mvn/local-repo \"${DEST_DIR}\"}' -M:dev"
echo ""
echo "Option 3 - Global (persists):"
echo "  mkdir -p ~/.clojure"
echo "  echo '{:mvn/local-repo \"${DEST_DIR}\"}' > ~/.clojure/deps.edn"
echo ""
echo "Verify:"
echo "  clojure -Spath | grep '.m2-cache'"
echo "──────────────────────────────────────"

# Clean up
rm "$BUNDLE_FILE"
echo ""
echo "✅ Ready to use!"

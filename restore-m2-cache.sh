#!/usr/bin/env bash
set -euo pipefail

# Restore M2 cache from GCS for any Clojure project
# Works in sandboxes or local environments
#
# Usage:
#   ./restore-m2-cache.sh [PROJECT_NAME] [TARBALL_URL]
#
# Examples:
#   ./restore-m2-cache.sh                    # Auto-detect project, fetch latest from GCS
#   ./restore-m2-cache.sh my-project         # Specific project, fetch latest from GCS
#   ./restore-m2-cache.sh my-project https://... # Use specific tarball URL

# Auto-detect project name from current directory
DEFAULT_PROJECT_NAME=$(basename "$PWD")
PROJECT_NAME=${1:-$DEFAULT_PROJECT_NAME}

# Optional direct URL
TARBALL_URL=${2:-}

# Configuration (can be overridden via environment)
BUCKET_NAME=${BUCKET_NAME:-gene-m2-cache}
M2_DEST=${M2_DEST:-$HOME/.m2-${PROJECT_NAME}}
TMP_DIR=${TMP_DIR:-/tmp}
TMP_TARBALL="$TMP_DIR/m2-${PROJECT_NAME}.tar.zst"

echo "===> M2 Cache Restore"
echo "     Project: $PROJECT_NAME"
echo "     Destination: $M2_DEST"
echo ""

# Download tarball
if [ -n "$TARBALL_URL" ]; then
    echo "===> Downloading from provided URL:"
    echo "     $TARBALL_URL"
    curl -L -o "$TMP_TARBALL" "$TARBALL_URL"
else
    # Fetch latest from GCS
    echo "===> Fetching latest M2 snapshot from GCS"
    GCS_PATH="gs://$BUCKET_NAME/m2/${PROJECT_NAME}/"

    echo "     Bucket: $GCS_PATH"

    # Get the most recent tarball
    LATEST=$(gcloud storage ls "$GCS_PATH" 2>/dev/null | grep '\.tar\.zst$' | sort -r | head -1 || true)

    if [ -z "$LATEST" ]; then
        echo ""
        echo "❌ Error: No M2 snapshots found at $GCS_PATH"
        echo ""
        echo "   Build and upload a snapshot first:"
        echo "   1. cd $PWD"
        echo "   2. ../server2/m2builder/build-m2-snapshot.sh"
        echo "   3. gcloud storage cp /tmp/m2-*.tar.zst $GCS_PATH"
        exit 1
    fi

    echo "     Latest: $(basename "$LATEST")"
    gcloud storage cp "$LATEST" "$TMP_TARBALL"
fi

echo ""
echo "===> Extracting to $M2_DEST"
rm -rf "$M2_DEST"
mkdir -p "$M2_DEST"

# Extract to temp location first
tar -C "$TMP_DIR" \
    -I 'zstd -d' \
    -xf "$TMP_TARBALL"

# Move the extracted directory to the destination
EXTRACTED_DIR=$(tar -tf "$TMP_TARBALL" | head -1 | cut -d/ -f1)
mv "$TMP_DIR/$EXTRACTED_DIR"/* "$M2_DEST/" 2>/dev/null || mv "$TMP_DIR/$EXTRACTED_DIR" "$M2_DEST"

echo ""
echo "===> ✅ M2 cache restored successfully!"
echo ""
echo "     Location: $M2_DEST"
echo "     Size: $(du -sh "$M2_DEST" | cut -f1)"
echo ""
echo "===> 🔧 Usage: Configure tools.deps to use this cache"
echo ""
echo "     Option 1 (Environment variable - recommended for sandboxes):"
echo "       export CLJ_CONFIG=/workspace/.clj-config-${PROJECT_NAME}"
echo "       mkdir -p \$CLJ_CONFIG"
echo "       echo '{:mvn/local-repo \"$M2_DEST\"}' > \$CLJ_CONFIG/deps.edn"
echo "       # Now all clojure commands will use the cache automatically"
echo ""
echo "     Option 2 (Per-command via -Sdeps):"
echo "       clojure -Sdeps '{:mvn/local-repo \"$M2_DEST\"}' [other args]"
echo ""
echo "     Option 3 (Global config - not recommended for sandboxes):"
echo "       mkdir -p ~/.clojure"
echo "       echo '{:mvn/local-repo \"$M2_DEST\"}' > ~/.clojure/deps.edn"
echo ""

# Clean up
rm -f "$TMP_TARBALL"

echo "===> Done!"

#!/usr/bin/env bash
# Build server2 M2 bundle (Maven dependencies only, excluding local/git deps)

set -euo pipefail

# Configuration
PROJECT_DIR="/Users/genekim/src.local/reddit-scraper-fulcro/server2"
BUNDLE_DIR="/Users/genekim/src.local/m2builder"
TIMESTAMP=$(date +%s)
M2_TEMP="/tmp/m2-server2-${TIMESTAMP}"
BUNDLE_FILE="/tmp/m2-server2-${TIMESTAMP}.tar.gz"

# GCS bucket and paths
GCS_BUCKET="gs://gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd"
GCS_M2_PATH="${GCS_BUCKET}/m2"

echo "════════════════════════════════════════════════════════════"
echo "Building server2 M2 Bundle (Maven deps only)"
echo "════════════════════════════════════════════════════════════"
echo "Project:     ${PROJECT_DIR}"
echo "Bundle file: ${BUNDLE_FILE}"
echo "Target:      ${GCS_M2_PATH}"
echo ""

# Step 1: Create temp M2 directory
echo "[1/6] Creating temp M2 directory..."
rm -rf "$M2_TEMP"
mkdir -p "$M2_TEMP"

# Step 2: Extract Maven-only deps from deps.edn
echo "[2/6] Creating Maven-only deps.edn..."
TEMP_DEPS="/tmp/server2-maven-only-deps.edn"

# Read the bundle definition instead (more accurate)
cat "${BUNDLE_DIR}/bundles/reddit-scraper-server2.edn" > "$TEMP_DEPS"

echo "  Using bundle definition: bundles/reddit-scraper-server2.edn"

# Step 3: Download dependencies
echo "[3/6] Downloading Maven dependencies..."
echo "  This may take 60-120 seconds..."

cd "$PROJECT_DIR"

# Use the bundle definition to download
clojure -Sdeps "$(cat "$TEMP_DEPS" | sed 's/:schema-version.*:deps/{:deps/' | sed 's/}}}$/}}/')" \
  -Sdeps "{:mvn/local-repo \"${M2_TEMP}\"}" \
  -Srepro \
  -Sforce \
  -P \
  -M:dev:test:run-tests

echo "  ✓ Downloaded"

# Step 4: Create tarball
echo "[4/6] Creating tarball..."
cd "$M2_TEMP"
tar -czf "$BUNDLE_FILE" .

BUNDLE_SIZE_MB=$(du -h "$BUNDLE_FILE" | cut -f1)
JAR_COUNT=$(find "$M2_TEMP" -name '*.jar' | wc -l | tr -d ' ')

echo "  ✓ Created: $BUNDLE_SIZE_MB ($JAR_COUNT JARs)"

# Step 5: Upload to GCS
echo "[5/6] Uploading to GCS..."
gsutil -q cp "$BUNDLE_FILE" "${GCS_M2_PATH}/reddit-scraper-server2-${TIMESTAMP}.tar.gz"

# Create 'latest' symlink (via metadata)
echo "[6/6] Creating latest link..."
gsutil -q cp "$BUNDLE_FILE" "${GCS_M2_PATH}/reddit-scraper-server2-latest.tar.gz"

# Create metadata
METADATA_FILE="/tmp/metadata-${TIMESTAMP}.json"
cat > "$METADATA_FILE" <<EOF
{
  "bundle_id": "reddit-scraper-server2",
  "timestamp": ${TIMESTAMP},
  "timestamp_iso": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "size_bytes": $(stat -f%z "$BUNDLE_FILE"),
  "size_mb": "${BUNDLE_SIZE_MB}",
  "artifact_count": ${JAR_COUNT},
  "source": "${PROJECT_DIR}/deps.edn",
  "gcs_url": "${GCS_M2_PATH}/reddit-scraper-server2-${TIMESTAMP}.tar.gz",
  "public_url": "https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-${TIMESTAMP}.tar.gz"
}
EOF

gsutil -q cp "$METADATA_FILE" "${GCS_M2_PATH}/metadata/reddit-scraper-server2-${TIMESTAMP}.json"
gsutil -q cp "$METADATA_FILE" "${GCS_M2_PATH}/metadata/reddit-scraper-server2-latest.json"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ Bundle built and uploaded successfully!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Bundle Details:"
echo "  Size:       ${BUNDLE_SIZE_MB}"
echo "  JARs:       ${JAR_COUNT}"
echo "  Timestamp:  ${TIMESTAMP}"
echo ""
echo "GCS Locations:"
echo "  Versioned:  ${GCS_M2_PATH}/reddit-scraper-server2-${TIMESTAMP}.tar.gz"
echo "  Latest:     ${GCS_M2_PATH}/reddit-scraper-server2-latest.tar.gz"
echo "  Metadata:   ${GCS_M2_PATH}/metadata/reddit-scraper-server2-${TIMESTAMP}.json"
echo ""
echo "Public Download URL:"
echo "  https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-${TIMESTAMP}.tar.gz"
echo ""
echo "Test download:"
echo "  curl -L -O https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-latest.tar.gz"
echo ""

# Clean up
rm -rf "$M2_TEMP"
rm "$BUNDLE_FILE"
rm "$TEMP_DEPS"
rm "$METADATA_FILE"

echo "🎉 Done!"

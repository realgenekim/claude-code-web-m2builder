#!/usr/bin/env bash
set -euo pipefail

# Test building a bundle locally (without GitHub Actions)
# Usage: ./test-bundle-local.sh bundles/bundle-name.edn

BUNDLE_FILE=${1:?Bundle file required. Usage: ./test-bundle-local.sh bundles/bundle-name.edn}

if [ ! -f "$BUNDLE_FILE" ]; then
    echo "Error: Bundle file not found: $BUNDLE_FILE"
    exit 1
fi

# Extract bundle ID
BUNDLE_ID=$(basename "$BUNDLE_FILE" .edn)

echo "=== Testing Bundle: $BUNDLE_ID ==="
echo "Bundle file: $BUNDLE_FILE"
echo ""

# Check for Clojure CLI
if ! command -v clojure &> /dev/null; then
    echo "Error: clojure CLI not found. Install from https://clojure.org/guides/install_clojure"
    exit 1
fi

# Create temp directory for M2 cache
TMP_M2="/tmp/m2-test-$BUNDLE_ID"
echo "Cleaning previous test cache: $TMP_M2"
rm -rf "$TMP_M2"
mkdir -p "$TMP_M2"

# Create temporary deps.edn from bundle definition
TEMP_DEPS_DIR="/tmp/bundle-test-$BUNDLE_ID"
rm -rf "$TEMP_DEPS_DIR"
mkdir -p "$TEMP_DEPS_DIR"

echo "Extracting deps from bundle definition..."

# Simply copy the bundle file - it's already a valid deps.edn structure
# Just use the :deps key directly
cp "$BUNDLE_FILE" "$TEMP_DEPS_DIR/deps.edn"

echo "Generated deps.edn:"
cat "$TEMP_DEPS_DIR/deps.edn"
echo ""

# Warm M2 cache
echo "Downloading dependencies to $TMP_M2..."
echo "This may take several minutes..."
echo ""

START_TIME=$(date +%s)

cd "$TEMP_DEPS_DIR"
if clojure -Srepro -Sforce \
           -Sdeps "{:mvn/local-repo \"$TMP_M2\"}" \
           -P; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo ""
    echo "=== Success! ==="
    echo ""
    echo "Build time: ${DURATION}s"

    # Count artifacts
    ARTIFACT_COUNT=$(find "$TMP_M2" -name "*.jar" | wc -l | tr -d ' ')
    echo "Artifacts downloaded: $ARTIFACT_COUNT JAR files"

    # Calculate size
    SIZE_KB=$(du -sk "$TMP_M2" | cut -f1)
    SIZE_MB=$((SIZE_KB / 1024))
    echo "Uncompressed size: ${SIZE_MB} MB"

    # Create tarball
    TARBALL="/tmp/m2-$BUNDLE_ID.tar.gz"
    echo ""
    echo "Creating tarball: $TARBALL"
    tar czf "$TARBALL" -C /tmp "m2-test-$BUNDLE_ID"

    TARBALL_SIZE_MB=$(du -m "$TARBALL" | cut -f1)
    COMPRESSION_RATIO=$(echo "scale=2; $SIZE_MB / $TARBALL_SIZE_MB" | bc)

    echo "Compressed size: ${TARBALL_SIZE_MB} MB"
    echo "Compression ratio: ${COMPRESSION_RATIO}x"
    echo ""
    echo "Tarball location: $TARBALL"
    echo ""
    echo "To test extraction:"
    echo "  mkdir -p ~/.m2-$BUNDLE_ID"
    echo "  tar xzf $TARBALL -C /tmp"
    echo "  mv /tmp/m2-test-$BUNDLE_ID/* ~/.m2-$BUNDLE_ID/"
    echo ""
    echo "To use with Clojure:"
    echo "  clojure -Sdeps '{:mvn/local-repo \"$HOME/.m2-$BUNDLE_ID\"}' ..."

else
    echo ""
    echo "=== Build Failed ==="
    echo "Check error messages above"
    exit 1
fi

# Cleanup temp deps dir
rm -rf "$TEMP_DEPS_DIR"

echo ""
echo "=== Test Complete ==="

#!/usr/bin/env bash
set -euo pipefail

# Build a project-scoped M2 snapshot for any Clojure project
# Can be run from any project directory, creates minimal M2 cache with only that project's dependencies
#
# Usage:
#   ./build-m2-snapshot.sh [PROJECT_NAME] [ALIASES]
#
# Examples:
#   ./build-m2-snapshot.sh                           # Auto-detect project name, use default aliases
#   ./build-m2-snapshot.sh my-project                # Specific name, default aliases
#   ./build-m2-snapshot.sh my-project :dev:test      # Specific name and aliases

# Auto-detect project name from current directory
DEFAULT_PROJECT_NAME=$(basename "$PWD")
PROJECT_NAME=${1:-$DEFAULT_PROJECT_NAME}

# Default aliases - can be overridden
DEFAULT_ALIASES=":dev:test"
ALIASES=${2:-$DEFAULT_ALIASES}

# Paths
TMP_M2_ROOT=/tmp/m2-${PROJECT_NAME}
TAR_OUT=/tmp/m2-${PROJECT_NAME}-$(date +%Y%m%d-%H%M%S).tar.zst

echo "===> M2 Snapshot Builder"
echo "     Project: $PROJECT_NAME"
echo "     Directory: $PWD"
echo "     Aliases: $ALIASES"
echo ""

# Check if deps.edn exists
if [ ! -f "deps.edn" ]; then
    echo "❌ Error: deps.edn not found in current directory"
    echo "   Run this script from a Clojure project root"
    exit 1
fi

echo "===> Cleaning temp m2: $TMP_M2_ROOT"
rm -rf "$TMP_M2_ROOT"
mkdir -p "$TMP_M2_ROOT"

echo "===> Preparing deps into $TMP_M2_ROOT"
echo "     This may take several minutes on first run..."
clojure \
  -Srepro \
  -Sforce \
  -Sdeps "{:mvn/local-repo \"${TMP_M2_ROOT}\"}" \
  -P \
  -M${ALIASES}

echo ""
echo "===> Creating tarball $TAR_OUT"
tar -C "$(dirname "$TMP_M2_ROOT")" \
    -I 'zstd -T0 -3' \
    -cf "$TAR_OUT" "$(basename "$TMP_M2_ROOT")"

echo ""
echo "===> ✅ M2 snapshot built successfully!"
echo ""
echo "     Project:  $PROJECT_NAME"
echo "     Size:     $(du -h "$TAR_OUT" | cut -f1)"
echo "     Location: $TAR_OUT"
echo ""
echo "===> 📤 Next steps:"
BUCKET_NAME=${BUCKET_NAME:-gene-m2-cache}
echo "     1. Upload to GCS:"
echo "        gcloud storage cp \"$TAR_OUT\" \"gs://$BUCKET_NAME/m2/${PROJECT_NAME}/\""
echo ""
echo "     2. Or if you have a Makefile with m2-upload target:"
echo "        make m2-upload"
echo ""

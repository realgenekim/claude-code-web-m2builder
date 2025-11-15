# M2 Builder - Maven Dependency Bundles for Sandboxed Environments

> **Status**: ✅ Proof of Concept Complete - **Google Cloud Storage Dependencies Successfully Tested!**

Build and distribute prewarmed Maven/Clojure `.m2` caches as downloadable bundles. Perfect for sandboxed coding environments (Codex CLI, Claude Code) that can't directly access Maven Central.

## 🎉 The Problem We Solved

**Challenge**: Google Cloud Storage Java client has 81 transitive dependencies and is notoriously difficult to work with in restricted environments.

**Solution**: Prebuilt `.m2` bundle that:
- ✅ Downloads in seconds (47 MB compressed)
- ✅ Contains all dependencies
- ✅ Works without Maven Central access
- ✅ No authentication required (public HTTPS URL)

## Test Results

**All bundles tested successfully on 2025-11-15:**

| Bundle | Build Time | Artifacts | Size | Status |
|--------|------------|-----------|------|--------|
| `clojure-minimal` | 3s | 3 JARs | 5 MB | ✅ |
| `web-stack` | 3s | 98 JARs | 17 MB | ✅ |
| **`gcs-client`** | **12s** | **81 JARs** | **47 MB** | ✅ **🔥** |

**Key Finding**: Original estimate for GCS was 450 MB. **Actual size: 47 MB (89% smaller!)**

See [TEST-RESULTS.md](TEST-RESULTS.md) for complete results.

## Quick Start

### Building Bundles Locally

```bash
# List available bundles
make list-deps

# Build a specific bundle
make bundle BUNDLE=clojure-minimal

# Build a bundle with specific output directory
make bundle BUNDLE=web-stack OUTPUT_DIR=dist

# Build all bundles
make bundle-all

# Clean built artifacts
make clean-bundles

# Get help
make help
```

Output bundles are saved to `output/` directory (default) as `m2-{bundle-id}.tar.gz`.

### Using Scripts Directly

```bash
# Test a bundle locally (alternative method)
./scripts/test-bundle-local.sh bundles/gcs-client.edn
```

## Documentation

**Start here**: [docs/INDEX.md](docs/INDEX.md)

- [docs/SUMMARY.md](docs/SUMMARY.md) - Executive summary
- [docs/interaction-example.md](docs/interaction-example.md) - Concrete walkthrough
- [docs/github-architecture.md](docs/github-architecture.md) - Full architecture
- [plans/implementation-plan.md](plans/implementation-plan.md) - Build roadmap
- [plans/testing-plan.md](plans/testing-plan.md) - Testing strategy

---

## Original M2 Builder (GCS-based)

The sections below describe the original GCS-based approach. The new GitHub-based architecture is described in the docs above.

---

# M2 Builder - Reusable M2 Cache Management

Reusable scripts for building and restoring project-scoped Maven M2 caches for any Clojure project.

## Quick Start

### From Any Project

```bash
# Navigate to your project
cd ../my-clojure-project

# Build M2 snapshot (auto-detects project name from directory)
../server2/m2builder/build-m2-snapshot.sh

# Or specify custom aliases
../server2/m2builder/build-m2-snapshot.sh my-project :dev:test:build
```

### In Sandboxes

```bash
# Restore latest snapshot for current project
../server2/m2builder/restore-m2-cache.sh

# Or specify project name
../server2/m2builder/restore-m2-cache.sh reddit-scraper
```

## Scripts

### build-m2-snapshot.sh

Creates a minimal M2 cache containing only dependencies for a specific project.

**Usage:**
```bash
./build-m2-snapshot.sh [PROJECT_NAME] [ALIASES]
```

**Arguments:**
- `PROJECT_NAME` (optional): Defaults to current directory name
- `ALIASES` (optional): Colon-separated aliases (default: `:dev:test`)

**Examples:**
```bash
# Auto-detect everything
cd ../reddit-scraper
../server2/m2builder/build-m2-snapshot.sh

# Custom project name
../server2/m2builder/build-m2-snapshot.sh my-app

# Custom aliases
../server2/m2builder/build-m2-snapshot.sh my-app :dev:test:nrepl:build

# From the same directory (server2)
cd server2
m2builder/build-m2-snapshot.sh
```

**Output:**
- Tarball: `/tmp/m2-{PROJECT_NAME}-{TIMESTAMP}.tar.zst`
- Size: ~2-3 GB (varies by project)
- Compression: zstd level 3 (fast, good compression)

### restore-m2-cache.sh

Downloads and extracts M2 cache from GCS.

**Usage:**
```bash
./restore-m2-cache.sh [PROJECT_NAME] [TARBALL_URL]
```

**Arguments:**
- `PROJECT_NAME` (optional): Defaults to current directory name
- `TARBALL_URL` (optional): Direct URL to tarball; if omitted, fetches latest from GCS

**Environment Variables:**
- `BUCKET_NAME` (default: `gene-m2-cache`): GCS bucket name
- `M2_DEST` (default: `$HOME/.m2-{PROJECT_NAME}`): Where to extract cache
- `TMP_DIR` (default: `/tmp`): Temporary download location

**Examples:**
```bash
# Auto-detect project, fetch latest from GCS
cd ../reddit-scraper
../server2/m2builder/restore-m2-cache.sh

# Specific project
../server2/m2builder/restore-m2-cache.sh server2

# Direct URL (signed URL or public)
../server2/m2builder/restore-m2-cache.sh server2 "https://storage.googleapis.com/..."

# Custom destination
M2_DEST=/workspace/.m2 ../server2/m2builder/restore-m2-cache.sh
```

## Using from Other Projects

### Option 1: Symlink (Recommended)

```bash
cd ../my-clojure-project
ln -s ../server2/m2builder m2builder

# Now you can use it locally
./m2builder/build-m2-snapshot.sh
```

### Option 2: Copy Directory

```bash
cp -r ../server2/m2builder ../my-clojure-project/
cd ../my-clojure-project
./m2builder/build-m2-snapshot.sh
```

### Option 3: Add to PATH

```bash
# In your ~/.bashrc or ~/.zshrc
export PATH="$PATH:$HOME/path/to/reddit-scraper-fulcro/server2/m2builder"

# Then from anywhere
cd ~/my-clojure-project
build-m2-snapshot.sh
```

### Option 4: Makefile Integration

Copy this to any project's Makefile:

```makefile
# GCS M2 Cache Configuration
BUCKET_NAME ?= gene-m2-cache
PROJECT_NAME ?= $(shell basename $(shell pwd))
M2BUILDER = ../server2/m2builder

m2-build:
	@echo "🔨 Building M2 snapshot..."
	$(M2BUILDER)/build-m2-snapshot.sh $(PROJECT_NAME)

m2-upload:
	@LATEST=$$(ls -t /tmp/m2-$(PROJECT_NAME)-*.tar.zst 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then echo "❌ No snapshot found"; exit 1; fi; \
	gcloud storage cp "$$LATEST" "gs://$(BUCKET_NAME)/m2/$(PROJECT_NAME)/"

m2-restore:
	$(M2BUILDER)/restore-m2-cache.sh $(PROJECT_NAME)

m2-snapshot: m2-build m2-upload

.PHONY: m2-build m2-upload m2-restore m2-snapshot
```

## How It Works

### Build Process

1. **Clean**: Removes any existing `/tmp/m2-{PROJECT_NAME}` directory
2. **Download**: Uses `clojure -P` with `-Sdeps '{:mvn/local-repo "/tmp/m2-{PROJECT_NAME}"}'` to download all dependencies to a project-specific location
3. **Compress**: Creates tarball with zstd compression
4. **Output**: Saves to `/tmp/m2-{PROJECT_NAME}-{TIMESTAMP}.tar.zst`

Key flags:
- `-Srepro`: Ignore user/global config (reproducible builds)
- `-Sforce`: Force re-resolution (fresh download)
- `-Sdeps '{:mvn/local-repo "..."}'`: Use custom M2 location
- `-P`: Prepare deps (download only, don't execute)
- `-M:aliases`: Include specified aliases

### Restore Process

1. **Download**: Fetches latest tarball from GCS or uses provided URL
2. **Extract**: Decompresses to `$M2_DEST` (default: `$HOME/.m2-{PROJECT_NAME}`)
3. **Configure**: Provides instructions for configuring tools.deps

## Configuring tools.deps to Use Cache

After restoring, configure Clojure to use the cache:

### For Sandboxes (Recommended)

```bash
export CLJ_CONFIG=/workspace/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'$HOME'/.m2-server2"}' > $CLJ_CONFIG/deps.edn

# Now all clojure commands use the cache
clojure -M:dev -m my.app
```

### Per-Command

```bash
clojure -Sdeps '{:mvn/local-repo "'$HOME'/.m2-server2"}' -M:dev -m my.app
```

### Global (Not Recommended for Sandboxes)

```bash
mkdir -p ~/.clojure
echo '{:mvn/local-repo "'$HOME'/.m2-server2"}' > ~/.clojure/deps.edn
```

## Why Project-Scoped Caches?

### vs. Full ~/.m2 Backup

| Approach | Size | Build Time | Reproducible | Portable |
|----------|------|------------|--------------|----------|
| Project-scoped | 2-3 GB | Medium | ✅ Yes | ✅ Yes |
| Full ~/.m2 | 10-50+ GB | Instant | ❌ No | ❌ No |

### Benefits

1. **Smaller**: Only includes dependencies for this project
2. **Reproducible**: Same deps.edn = same cache
3. **Portable**: Works across different machines/environments
4. **Lower cost**: Less GCS egress fees
5. **Faster restore**: Smaller download and extraction

## Troubleshooting

### "deps.edn not found"

Run the script from a Clojure project root directory.

### "No M2 snapshots found"

Build and upload a snapshot first:
```bash
./build-m2-snapshot.sh
gcloud storage cp /tmp/m2-*.tar.zst gs://your-bucket/m2/your-project/
```

### Dependencies still downloading

Verify tools.deps is configured:
```bash
clojure -Spath | grep -o '/[^:]*\.m2'
# Should show your custom M2 path
```

### Stale cache

Rebuild when deps.edn changes:
```bash
./build-m2-snapshot.sh
# Upload new version
```

## Related

- [GCS_M2_CACHE.md](../GCS_M2_CACHE.md) - Detailed documentation and cost analysis
- [server2/Makefile](../Makefile) - Example integration

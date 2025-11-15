# M2 Bundle System Implementation Plan

## Overview

Transform the existing m2builder scripts into a **community-driven GitHub-based bundle library** that allows sandboxed coding agents to share prewarmed Maven/Clojure dependency caches.

## Current State Analysis

**Existing assets** (in this repo):
- ✅ `build-m2-snapshot.sh` - Creates project-scoped .m2 tarballs
- ✅ `restore-m2-cache.sh` - Downloads and extracts from GCS
- ✅ Basic documentation

**Current limitations**:
- ❌ Requires GCS and `gcloud` CLI
- ❌ No standardized bundle format
- ❌ No community contribution model
- ❌ No automated build pipeline

**Target state**:
- ✅ GitHub-only (no GCS dependency)
- ✅ Community bundle library
- ✅ Automated CI/CD via GitHub Actions
- ✅ Public download URLs (no auth required)
- ✅ Request/response "mailbox" for agent communication

---

## Phase 1: Core Infrastructure (Week 1)

### 1.1 Bundle Schema Design

**Create**: `docs/bundle-schema.md`

**Define EDN format**:
```clojure
{:bundle-id "web-stack"                    ; Required: Unique identifier
 :version "1.0.0"                          ; Required: Semver
 :description "Ring + HTTP-Kit + Cheshire" ; Required: Human-readable
 :maintainer "@github-handle"              ; Required: Who to contact
 :tags ["web" "http" "json"]               ; Optional: Searchability
 :deps                                     ; Required: Clojure deps map
 {ring/ring-core {:mvn/version "1.12.2"}
  http-kit/http-kit {:mvn/version "2.8.0"}
  cheshire/cheshire {:mvn/version "5.12.0"}}}
```

**Validation rules**:
- `:bundle-id` must be kebab-case, alphanumeric + hyphens
- `:version` must be valid semver
- `:deps` must be valid tools.deps format
- Total uncompressed size target: < 2 GB

### 1.2 Repository Structure

**Create directories**:
```bash
mkdir -p bundles
mkdir -p deps-requests
mkdir -p deps-responses
mkdir -p .github/workflows
mkdir -p scripts
mkdir -p examples
```

**Add gitkeep files**:
```bash
touch deps-requests/.gitkeep
touch deps-responses/.gitkeep
```

**.gitignore additions**:
```gitignore
# Ignore actual response files (transient)
deps-responses/*.edn
!deps-responses/.gitkeep

# Ignore temp build artifacts
/tmp/
*.tar.gz
*.tar.zst
```

### 1.3 Initial Bundle Definitions

**Create 3 starter bundles**:

**`bundles/clojure-core.edn`**:
```clojure
{:bundle-id "clojure-core"
 :version "1.0.0"
 :description "Pure Clojure stdlib (1.11.3 + tools)"
 :maintainer "@realgenekim"
 :tags ["core" "minimal"]
 :deps
 {org.clojure/clojure {:mvn/version "1.11.3"}
  org.clojure/tools.cli {:mvn/version "1.1.230"}
  org.clojure/tools.logging {:mvn/version "1.3.0"}}}
```

**`bundles/web-stack.edn`**:
```clojure
{:bundle-id "web-stack"
 :version "1.0.0"
 :description "Ring + HTTP-Kit + Cheshire + Compojure"
 :maintainer "@realgenekim"
 :tags ["web" "http" "rest" "json"]
 :deps
 {ring/ring-core {:mvn/version "1.12.2"}
  ring/ring-jetty-adapter {:mvn/version "1.12.2"}
  http-kit/http-kit {:mvn/version "2.8.0"}
  cheshire/cheshire {:mvn/version "5.12.0"}
  compojure/compojure {:mvn/version "1.7.1"}}}
```

**`bundles/gcs-client.edn`**:
```clojure
{:bundle-id "gcs-client"
 :version "1.0.0"
 :description "Google Cloud Storage Java client"
 :maintainer "@realgenekim"
 :tags ["google-cloud" "storage" "gcs"]
 :deps
 {com.google.cloud/google-cloud-storage {:mvn/version "2.52.0"}}}
```

### 1.4 Bundle Registry

**Create**: `bundles/README.md`

```markdown
# M2 Bundle Registry

Community-maintained Maven/Clojure dependency bundles for sandboxed environments.

## Available Bundles

| Bundle ID | Description | Estimated Size | Maintainer |
|-----------|-------------|----------------|------------|
| `clojure-core` | Pure Clojure stdlib | ~15 MB | @realgenekim |
| `web-stack` | Ring + HTTP-Kit + Cheshire | ~45 MB | @realgenekim |
| `gcs-client` | Google Cloud Storage client | ~120 MB | @realgenekim |

## Usage

### Option 1: Reference by ID
```clojure
{:bundle-id "web-stack"}
```

### Option 2: Extend a bundle
```clojure
{:bundle-id "web-stack"
 :extra-deps {hiccup/hiccup {:mvn/version "2.0.0"}}}
```

### Option 3: Compose multiple bundles
```clojure
{:bundle-ids ["clojure-core" "web-stack"]}
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on adding new bundles.
```

**Success criteria**:
- [ ] Bundle schema documented
- [ ] Repository structure created
- [ ] 3 initial bundles defined
- [ ] Bundle registry created

---

## Phase 2: GitHub Actions Workflows (Week 1-2)

### 2.1 Bundle Build Workflow

**Create**: `.github/workflows/build-bundle.yml`

**Triggers**:
- `push` to `bundles/*.edn` (new/updated bundle definitions)
- `push` to `deps-requests/*.edn` (ad-hoc requests)
- `workflow_dispatch` (manual testing)

**Jobs**:

```yaml
name: Build M2 Bundle

on:
  push:
    paths:
      - 'bundles/*.edn'
      - 'deps-requests/*.edn'
  workflow_dispatch:
    inputs:
      bundle-id:
        description: 'Bundle ID to build'
        required: true

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      bundles: ${{ steps.changed.outputs.bundles }}
      requests: ${{ steps.changed.outputs.requests }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Detect changed bundles and requests
        id: changed
        run: |
          # Get changed files
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            echo "bundles=bundles/${{ github.event.inputs.bundle-id }}.edn" >> $GITHUB_OUTPUT
            echo "requests=" >> $GITHUB_OUTPUT
          else
            BUNDLES=$(git diff --name-only HEAD~1 HEAD | grep '^bundles/.*\.edn$' | tr '\n' ' ')
            REQUESTS=$(git diff --name-only HEAD~1 HEAD | grep '^deps-requests/.*\.edn$' | tr '\n' ' ')
            echo "bundles=$BUNDLES" >> $GITHUB_OUTPUT
            echo "requests=$REQUESTS" >> $GITHUB_OUTPUT
          fi

  build-bundles:
    needs: detect-changes
    if: needs.detect-changes.outputs.bundles != ''
    runs-on: ubuntu-latest
    strategy:
      matrix:
        bundle: ${{ fromJSON(format('[{0}]', needs.detect-changes.outputs.bundles)) }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Clojure
        uses: DeLaGuardo/setup-clojure@12.5
        with:
          cli: 1.11.3.1463

      - name: Extract bundle ID
        id: meta
        run: |
          BUNDLE_FILE="${{ matrix.bundle }}"
          BUNDLE_ID=$(basename "$BUNDLE_FILE" .edn)
          echo "bundle-id=$BUNDLE_ID" >> $GITHUB_OUTPUT

      - name: Build M2 cache
        run: |
          # Create temp deps.edn from bundle definition
          mkdir -p /tmp/build-${{ steps.meta.outputs.bundle-id }}

          # Parse EDN and create deps.edn
          # (Simplified - in real implementation, use proper EDN parser)
          cat ${{ matrix.bundle }} | \
            grep -A 100 ':deps' | \
            sed '1s/.*:deps//' | \
            sed 's/^/{:deps /' | \
            sed '$s/$/}/' \
            > /tmp/build-${{ steps.meta.outputs.bundle-id }}/deps.edn

          # Warm M2
          cd /tmp/build-${{ steps.meta.outputs.bundle-id }}
          clojure -Srepro -Sforce \
                  -Sdeps "{:mvn/local-repo \"/tmp/m2-${{ steps.meta.outputs.bundle-id }}\"}" \
                  -P

      - name: Create tarball
        run: |
          cd /tmp
          tar czf m2-${{ steps.meta.outputs.bundle-id }}.tar.gz m2-${{ steps.meta.outputs.bundle-id }}

      - name: Upload artifact (temp)
        uses: actions/upload-artifact@v4
        with:
          name: m2-${{ steps.meta.outputs.bundle-id }}
          path: /tmp/m2-${{ steps.meta.outputs.bundle-id }}.tar.gz
          retention-days: 1

      - name: Create or update release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: m2-bundles
          name: M2 Bundles
          draft: false
          prerelease: false
          body: |
            Community-maintained M2 bundles for Clojure projects.

            Download bundles with:
            ```bash
            curl -L -O https://github.com/${{ github.repository }}/releases/download/m2-bundles/m2-BUNDLE-ID.tar.gz
            ```
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload to release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: m2-bundles
          files: /tmp/m2-${{ steps.meta.outputs.bundle-id }}.tar.gz
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Print summary
        run: |
          echo "### ✅ Bundle Built: ${{ steps.meta.outputs.bundle-id }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Download URL:**" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
          echo "https://github.com/${{ github.repository }}/releases/download/m2-bundles/m2-${{ steps.meta.outputs.bundle-id }}.tar.gz" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Size:** $(du -h /tmp/m2-${{ steps.meta.outputs.bundle-id }}.tar.gz | cut -f1)" >> $GITHUB_STEP_SUMMARY

  build-requests:
    needs: detect-changes
    if: needs.detect-changes.outputs.requests != ''
    runs-on: ubuntu-latest
    # Similar to build-bundles, but also writes response file
    steps:
      # ... (similar to above, plus response file generation)

      - name: Write response
        run: |
          cat > deps-responses/${{ steps.meta.outputs.job-id }}.edn <<EOF
          {:job-id "${{ steps.meta.outputs.job-id }}"
           :status :ok
           :bundle-url "https://github.com/${{ github.repository }}/releases/download/m2-bundles/m2-${{ steps.meta.outputs.job-id }}.tar.gz"
           :created-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
           :workflow-run "${{ github.run_id }}"}
          EOF

      - name: Commit response
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add deps-responses/
          git commit -m "Add response for ${{ steps.meta.outputs.job-id }}"
          git push
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 2.2 Validation Workflow

**Create**: `.github/workflows/validate-bundle.yml`

**Purpose**: Validate PRs that add/modify bundles

**Checks**:
- EDN syntax validity
- Required fields present
- Bundle ID uniqueness
- Size estimation (warn if > 500 MB)

### 2.3 Cleanup Workflow

**Create**: `.github/workflows/cleanup.yml`

**Purpose**: Keep repo tidy

**Triggers**:
- `schedule`: Daily cron
- `workflow_dispatch`: Manual

**Actions**:
- Delete old request/response files (> 7 days)
- Delete old workflow artifacts (> 3 days)

**Success criteria**:
- [ ] Build workflow functional
- [ ] Validation workflow catches errors
- [ ] Cleanup workflow maintains hygiene
- [ ] Manual test: Add bundle → workflow builds → Release asset created

---

## Phase 3: Client Scripts (Week 2)

### 3.1 Request Bundle Script

**Create**: `scripts/request-bundle.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Request an M2 bundle (for use by agents/wrappers)
# Usage: ./request-bundle.sh BUNDLE_ID [EXTRA_DEPS_EDN]

BUNDLE_ID=${1:?Bundle ID required}
EXTRA_DEPS=${2:-"{}"}
JOB_ID="job-$(date +%s)-$(openssl rand -hex 4)"

cat > deps-requests/$JOB_ID.edn <<EOF
{:job-id "$JOB_ID"
 :bundle-id "$BUNDLE_ID"
 :extra-deps $EXTRA_DEPS
 :requested-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF

echo "Request created: $JOB_ID"
echo "Now: git add deps-requests/$JOB_ID.edn && git commit -m 'Request $BUNDLE_ID' && git push"
```

### 3.2 Wait for Bundle Script

**Create**: `scripts/wait-for-bundle.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

JOB_ID=${1:?Job ID required}
TIMEOUT=${2:-300}  # 5 minutes default

echo "Waiting for bundle $JOB_ID (timeout: ${TIMEOUT}s)..."

start=$SECONDS
while [ $((SECONDS - start)) -lt $TIMEOUT ]; do
  git pull -q origin main 2>/dev/null || true

  if [ -f "deps-responses/$JOB_ID.edn" ]; then
    echo "✅ Response received!"
    cat "deps-responses/$JOB_ID.edn"
    exit 0
  fi

  echo -n "."
  sleep 10
done

echo ""
echo "❌ Timeout waiting for bundle"
exit 1
```

### 3.3 Download Bundle Script

**Create**: `scripts/download-bundle.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Download and extract M2 bundle
# Usage: ./download-bundle.sh BUNDLE_ID [DEST_DIR]

BUNDLE_ID=${1:?Bundle ID required}
DEST_DIR=${2:-$HOME/.m2-cache/$BUNDLE_ID}

RELEASE_URL="https://github.com/realgenekim/m2builder/releases/download/m2-bundles/m2-$BUNDLE_ID.tar.gz"

echo "Downloading $BUNDLE_ID from GitHub..."
echo "  URL: $RELEASE_URL"
echo "  Dest: $DEST_DIR"

# Download
mkdir -p /tmp/m2-downloads
curl -L -o "/tmp/m2-downloads/$BUNDLE_ID.tar.gz" "$RELEASE_URL"

# Extract
mkdir -p "$DEST_DIR"
tar xzf "/tmp/m2-downloads/$BUNDLE_ID.tar.gz" -C "$DEST_DIR" --strip-components=1

echo "✅ Bundle ready at: $DEST_DIR"
echo ""
echo "Usage:"
echo "  clojure -Sdeps '{:mvn/local-repo \"$DEST_DIR\"}' ..."
```

### 3.4 All-in-One Wrapper

**Create**: `scripts/use-bundle.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# One-stop script: request (if needed), wait, download, configure
# Usage: ./use-bundle.sh BUNDLE_ID

BUNDLE_ID=${1:?Bundle ID required}
CACHE_DIR="$HOME/.m2-cache/$BUNDLE_ID"

# Check if already cached
if [ -d "$CACHE_DIR" ] && [ -f "$CACHE_DIR/repository" ]; then
  echo "✅ Bundle $BUNDLE_ID already cached at $CACHE_DIR"
  exit 0
fi

# Check if bundle definition exists (prebuilt)
if [ -f "bundles/$BUNDLE_ID.edn" ]; then
  echo "Using prebuilt bundle: $BUNDLE_ID"
  ./scripts/download-bundle.sh "$BUNDLE_ID"
  exit 0
fi

# Otherwise, create request
echo "Bundle not found locally, creating request..."
./scripts/request-bundle.sh "$BUNDLE_ID"

git add deps-requests/
git commit -m "Request bundle: $BUNDLE_ID"
git push

# Wait for build
JOB_ID=$(ls -t deps-requests/*.edn | head -1 | xargs basename .edn)
./scripts/wait-for-bundle.sh "$JOB_ID"

# Download
RESPONSE_FILE="deps-responses/$JOB_ID.edn"
BUNDLE_URL=$(grep ':bundle-url' "$RESPONSE_FILE" | cut -d'"' -f2)

mkdir -p "$CACHE_DIR"
curl -L -o "/tmp/$JOB_ID.tar.gz" "$BUNDLE_URL"
tar xzf "/tmp/$JOB_ID.tar.gz" -C "$CACHE_DIR" --strip-components=1

echo "✅ Bundle ready at: $CACHE_DIR"
```

**Success criteria**:
- [ ] Scripts functional end-to-end
- [ ] Documentation for each script
- [ ] Examples in README

---

## Phase 4: Documentation & Examples (Week 2-3)

### 4.1 Main README Update

**Update**: `README.md`

**Add sections**:
1. **Overview** (what is this, why use it)
2. **Quick Start** (use-bundle.sh one-liner)
3. **Available Bundles** (link to bundles/README.md)
4. **For Contributors** (link to CONTRIBUTING.md)
5. **Architecture** (link to docs/github-architecture.md)
6. **FAQ**

### 4.2 Contributing Guide

**Create**: `CONTRIBUTING.md`

**Sections**:
1. How to add a new bundle
2. Bundle guidelines (size, naming, maintainer responsibilities)
3. How to test locally
4. PR process

### 4.3 Examples

**Create**: `examples/`

**Example 1**: `examples/sandbox-docker/`
- Dockerfile that uses a bundle
- docker-compose.yml
- README

**Example 2**: `examples/codex-wrapper/`
- Shell script that wraps Codex CLI
- Monitors for "NEED_DEPS" in output
- Automatically requests/downloads bundles

**Example 3**: `examples/makefile-integration/`
- Sample Makefile with bundle targets
- Can be copied to any project

**Success criteria**:
- [ ] README comprehensive and clear
- [ ] CONTRIBUTING.md guides new contributors
- [ ] 3 working examples
- [ ] All docs cross-linked

---

## Phase 5: Testing & Refinement (Week 3)

### 5.1 End-to-End Tests

**Create**: `.github/workflows/e2e-test.yml`

**Test flow**:
1. Create test bundle definition
2. Trigger build workflow
3. Wait for Release asset
4. Download and verify tarball
5. Extract and verify .m2 structure
6. Cleanup

### 5.2 Local Testing

**Create**: `scripts/test-bundle-local.sh`

**Purpose**: Test bundle builds without pushing to GitHub

```bash
# Build bundle locally using same logic as CI
./scripts/test-bundle-local.sh bundles/web-stack.edn
# Output: /tmp/m2-web-stack.tar.gz
```

### 5.3 Performance Benchmarks

**Document**:
- Bundle build times (by size)
- Download speeds (GitHub CDN)
- Extraction times
- Comparison: GitHub vs GCS

### 5.4 Cost Analysis

**Create**: `docs/cost-analysis.md`

**Compare**:
- GitHub (public repo)
- GitHub (private repo)
- GCS
- Self-hosted

**Success criteria**:
- [ ] E2E tests pass
- [ ] Local testing workflow documented
- [ ] Performance benchmarks collected
- [ ] Cost analysis complete

---

## Phase 6: Migration from GCS (Optional, Week 4)

### 6.1 Dual Mode Support

**Update existing scripts**:
- `restore-m2-cache.sh` → support both GCS and GitHub sources
- Add `--source github|gcs` flag

### 6.2 Migration Script

**Create**: `scripts/migrate-gcs-to-github.sh`

**Purpose**: One-time migration of existing GCS bundles to GitHub Releases

**Steps**:
1. List all tarballs in GCS bucket
2. For each tarball:
   - Download from GCS
   - Upload to GitHub Release
   - Verify
3. Print summary

### 6.3 Deprecation Plan

**Timeline**:
- Week 4: Announce GitHub-first approach
- Week 5-6: Dual mode (both GCS and GitHub work)
- Week 7+: GCS deprecated, remove from docs

**Success criteria**:
- [ ] Existing users can migrate smoothly
- [ ] No breaking changes
- [ ] Clear deprecation timeline

---

## Acceptance Criteria (Overall)

### Must Have (MVP)
- [x] Bundle schema defined and documented
- [ ] 3+ working community bundles
- [ ] GitHub Actions workflow builds bundles automatically
- [ ] Public Release URLs for bundle downloads
- [ ] Client scripts for request/download/use
- [ ] End-to-end flow tested: bundle def → build → download → use
- [ ] Clear README and contribution guide

### Should Have
- [ ] 10+ community bundles covering common stacks
- [ ] Validation workflow for PRs
- [ ] Cleanup workflow for old artifacts
- [ ] Examples for Docker, Makefile, wrapper scripts
- [ ] Cost and performance documentation

### Nice to Have
- [ ] Web UI for browsing bundles (GitHub Pages)
- [ ] Bundle composition (merge multiple bundles)
- [ ] Bundle versioning (tags beyond m2-bundles)
- [ ] Metrics/analytics (download counts via GitHub API)
- [ ] Slack/Discord bot for bundle notifications

---

## Rollout Plan

### Week 1
- Phase 1: Core infrastructure
- Phase 2: Start build workflow

### Week 2
- Phase 2: Finish workflows
- Phase 3: Client scripts

### Week 3
- Phase 4: Documentation
- Phase 5: Testing

### Week 4
- Phase 5: Benchmarks and cost analysis
- Phase 6: Migration (if applicable)
- Public announcement

### Week 5+
- Community growth
- Bundle contributions
- Iterate based on feedback

---

## Success Metrics

**Adoption**:
- GitHub stars on repo
- Number of contributors
- Number of community-submitted bundles

**Usage**:
- Release asset downloads (via GitHub API)
- Workflow runs per week
- Active bundle users (via surveys/feedback)

**Quality**:
- Average bundle build time < 5 min
- <5% failed builds
- < 1 day response time for bundle requests

**Cost**:
- Public repo: $0/month
- Private repo (if applicable): < $1/month

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| GitHub rate limits | Low | High | Use authenticated API calls, monitor quotas |
| Bundle size explosion | Medium | Medium | Validation workflow warns at 500 MB, rejects > 1 GB |
| Malicious bundle contributions | Medium | High | PR review process, bundle validation, maintainer approval |
| GitHub Actions quota exceeded | Low | Medium | Use public repo (unlimited), or monitor usage alerts |
| EDN parsing errors | High | Low | Validation workflow, comprehensive tests |
| Storage costs for private repo | Low | Low | Short artifact retention, monitor billing |

---

## Next Steps

**Immediate actions**:
1. Create `docs/bundle-schema.md`
2. Set up repository structure (directories, .gitkeep)
3. Create 3 initial bundle definitions
4. Draft `.github/workflows/build-bundle.yml`
5. Test workflow locally with `act` or similar
6. Push to GitHub, trigger first build

**Decision points**:
- [ ] Public or private repo? (Recommend: **public**)
- [ ] Repo name? (Current: `m2builder`, could rename to `clojure-m2-bundles`)
- [ ] Org or personal repo? (Could move to organization later)
- [ ] Use existing repo or create new? (Can evolve existing)

**Owner**: @realgenekim (you!)

**Collaborators**: Open to community after MVP

---

## Appendix: Alternative Approaches Considered

### A. Continue with GCS
**Pros**: Already working, familiar
**Cons**: Requires gcloud, auth complexity, cost
**Decision**: Migrate to GitHub for better DX

### B. Use GitHub Packages (GHCR)
**Pros**: Built for container images
**Cons**: Overkill for tarballs, requires Docker
**Decision**: Use Releases (simpler)

### C. Use Artifacts Only (no Releases)
**Pros**: Simpler workflow
**Cons**: Requires auth for download, short retention
**Decision**: Use Releases for long-term public URLs

### D. Use External CDN (Cloudflare R2, etc.)
**Pros**: Cheaper egress than GCS
**Cons**: More infrastructure, auth complexity
**Decision**: GitHub Releases sufficient (free for public)

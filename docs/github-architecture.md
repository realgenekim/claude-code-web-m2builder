# GitHub-Based M2 Bundle Architecture

## Overview

A complete architecture for sharing Maven/Clojure dependency bundles between sandboxed coding agents using **only GitHub** (no GCS, no `gcloud`).

## Core Concept

**GitHub serves three roles:**
1. **Message bus** (inbox/outbox via files in repo)
2. **Build system** (GitHub Actions as networked agent)
3. **Artifact storage** (Release assets with public HTTPS URLs)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        SANDBOXED AGENT                          │
│  (Codex CLI / Claude Code - no network / no gcloud)            │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ 1. Writes deps manifest
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LOCAL HOST WRAPPER                           │
│  (Your laptop - has GitHub auth via PAT or gh CLI)             │
│                                                                 │
│  • Monitors sandbox output or shared folder                    │
│  • Commits deps-requests/job-123.edn                           │
│  • Pushes to GitHub                                            │
│  • Pulls responses                                             │
│  • Downloads bundle tarballs                                   │
│  • Mounts .m2 into sandbox container                           │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ 2. git push
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GITHUB REPOSITORY                          │
│  (Public or private - free for public)                         │
│                                                                 │
│  ├── deps-requests/                                            │
│  │   ├── job-123.edn          ← Request manifests             │
│  │   └── job-456.edn                                          │
│  ├── deps-responses/                                           │
│  │   ├── job-123.edn          ← Response manifests            │
│  │   └── job-456.edn                                          │
│  ├── bundles/                                                  │
│  │   ├── clojure-core.edn     ← Community bundle defs         │
│  │   ├── web-stack.edn                                        │
│  │   └── gcs-client.edn                                       │
│  └── .github/workflows/                                        │
│      └── build-bundle.yml      ← CI workflow                  │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ 3. Workflow trigger
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS RUNNER                        │
│  (Networked environment - can access Maven Central)            │
│                                                                 │
│  1. Reads deps manifest                                        │
│  2. Runs: clojure -P (downloads deps to temp .m2)             │
│  3. Creates: m2-job-123.tar.gz                                 │
│  4. Uploads to GitHub Release as asset                         │
│  5. Writes deps-responses/job-123.edn with URL                 │
│  6. Commits response back to repo                              │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ 4. Release asset created
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                     GITHUB RELEASES                             │
│  (Tag: m2-bundles)                                             │
│                                                                 │
│  Assets:                                                       │
│  • m2-job-123.tar.gz                                           │
│  • m2-clojure-core.tar.gz                                      │
│  • m2-web-stack.tar.gz                                         │
│                                                                 │
│  Public URL (no auth!):                                        │
│  https://github.com/owner/repo/releases/download/              │
│         m2-bundles/m2-job-123.tar.gz                           │
└─────────────────────────────────────────────────────────────────┘
                        │
                        │ 5. curl download (no auth)
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LOCAL HOST WRAPPER                           │
│  Downloads tarball, extracts to ~/.m2-cache/job-123/          │
│  Mounts into sandbox container                                 │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ 6. Bind mount
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SANDBOXED AGENT                             │
│  Uses .m2 cache for compilation/REPL                           │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Flow

### Step 1: Request Creation (Sandbox → Git)

**Sandbox writes manifest**:
```bash
# Inside sandbox or via wrapper
cat > deps-requests/job-123.edn <<EOF
{:job-id "job-123"
 :bundle-id "web-stack"  ; or inline deps
 :deps {ring/ring-core {:mvn/version "1.12.2"}
        http-kit/http-kit {:mvn/version "2.8.0"}}}
EOF
```

**Host wrapper commits and pushes**:
```bash
git add deps-requests/job-123.edn
git commit -m "Request: web-stack deps for job-123"
git push origin main
```

**Auth**: Uses existing GitHub credentials (`gh auth login` or `GITHUB_TOKEN`)

---

### Step 2: GitHub Actions Build

**Workflow trigger** (`.github/workflows/build-bundle.yml`):
```yaml
name: Build M2 Bundle

on:
  push:
    paths:
      - 'deps-requests/*.edn'
  workflow_dispatch:

jobs:
  build-bundles:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Clojure
        uses: DeLaGuardo/setup-clojure@12.5
        with:
          cli: 1.11.3.1463

      - name: Find new requests
        id: requests
        run: |
          # Get list of new .edn files
          REQUESTS=$(git diff --name-only HEAD~1 HEAD | grep '^deps-requests/.*\.edn$' || echo "")
          echo "files=$REQUESTS" >> $GITHUB_OUTPUT

      - name: Process each request
        if: steps.requests.outputs.files != ''
        run: |
          for REQUEST_FILE in ${{ steps.requests.outputs.files }}; do
            JOB_ID=$(basename "$REQUEST_FILE" .edn)
            echo "Processing $JOB_ID..."

            # Read deps from request
            # (simplified - real version would parse EDN properly)

            # Create temp deps.edn
            mkdir -p /tmp/m2-$JOB_ID
            cp "$REQUEST_FILE" /tmp/deps-$JOB_ID.edn

            # Warm M2
            clojure -Sdeps "$(cat /tmp/deps-$JOB_ID.edn)" \
                    -Srepro \
                    -Sforce \
                    -Sdeps "{:mvn/local-repo \"/tmp/m2-$JOB_ID\"}" \
                    -P

            # Create tarball
            tar czf "m2-$JOB_ID.tar.gz" -C /tmp "m2-$JOB_ID"

            # Upload to Release
            gh release upload m2-bundles "m2-$JOB_ID.tar.gz" --clobber

            # Write response
            cat > "deps-responses/$JOB_ID.edn" <<EOF
            {:job-id "$JOB_ID"
             :status :ok
             :url "https://github.com/${{ github.repository }}/releases/download/m2-bundles/m2-$JOB_ID.tar.gz"
             :created-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
            EOF
          done

      - name: Commit responses
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add deps-responses/
          git commit -m "Add responses for processed bundles" || echo "No changes"
          git push
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

### Step 3: Response Retrieval (Git → Host)

**Host wrapper polls for response**:
```bash
#!/usr/bin/env bash
# wait-for-bundle.sh

JOB_ID=$1
TIMEOUT=${2:-300}  # 5 minutes default

echo "Waiting for bundle $JOB_ID..."

start=$SECONDS
while [ $((SECONDS - start)) -lt $TIMEOUT ]; do
  git pull -q origin main

  if [ -f "deps-responses/$JOB_ID.edn" ]; then
    echo "Response received!"
    cat "deps-responses/$JOB_ID.edn"
    exit 0
  fi

  sleep 10
done

echo "Timeout waiting for bundle"
exit 1
```

---

### Step 4: Bundle Download & Mount

**Download and extract**:
```bash
#!/usr/bin/env bash
# download-bundle.sh

JOB_ID=$1
RESPONSE_FILE="deps-responses/$JOB_ID.edn"

# Parse URL from response (simplified - use proper EDN parser)
BUNDLE_URL=$(grep ':url' "$RESPONSE_FILE" | cut -d'"' -f2)

echo "Downloading $BUNDLE_URL..."

# Download (no auth needed for Release assets!)
curl -L -o "/tmp/m2-$JOB_ID.tar.gz" "$BUNDLE_URL"

# Extract
mkdir -p "$HOME/.m2-cache/$JOB_ID"
tar xzf "/tmp/m2-$JOB_ID.tar.gz" -C "$HOME/.m2-cache/"

echo "Bundle ready at: $HOME/.m2-cache/m2-$JOB_ID"
```

**Mount into sandbox**:
```bash
# Example for Docker-based sandbox
docker run \
  -v "$HOME/.m2-cache/m2-$JOB_ID:/root/.m2:ro" \
  -v "$(pwd):/workspace" \
  clojure:temurin-21-tools-deps \
  clojure -M:dev -m my.app
```

---

## Community Bundle Model

Instead of ad-hoc job requests, support **reusable bundles**:

### Bundle Definition

**File**: `bundles/web-stack.edn`
```clojure
{:bundle-id "web-stack"
 :description "Ring + HTTP-Kit + Cheshire web stack"
 :maintainer "@yourhandle"
 :deps
 {ring/ring-core {:mvn/version "1.12.2"}
  ring/ring-jetty-adapter {:mvn/version "1.12.2"}
  http-kit/http-kit {:mvn/version "2.8.0"}
  cheshire/cheshire {:mvn/version "5.12.0"}
  compojure/compojure {:mvn/version "1.7.1"}}}
```

### Bundle Registry

**File**: `bundles/README.md`
```markdown
# Available M2 Bundles

| Bundle ID | Description | Size | Last Updated |
|-----------|-------------|------|--------------|
| clojure-core | Pure Clojure stdlib | 15 MB | 2025-11-14 |
| web-stack | Ring + HTTP-Kit + Cheshire | 45 MB | 2025-11-14 |
| gcs-client | Google Cloud Storage client | 120 MB | 2025-11-13 |
| data-science | Tablecloth + tech.ml.dataset | 200 MB | 2025-11-12 |

## Usage

1. Reference by bundle-id in your request:
   ```clojure
   {:bundle-id "web-stack"}
   ```

2. Or compose multiple bundles:
   ```clojure
   {:bundle-ids ["clojure-core" "web-stack"]}
   ```

3. Or extend a bundle:
   ```clojure
   {:bundle-id "web-stack"
    :extra-deps {hiccup/hiccup {:mvn/version "2.0.0"}}}
   ```
```

### Community Contribution Workflow

**Adding a new bundle**:
```bash
# 1. Fork repo
# 2. Create bundle definition
cat > bundles/my-stack.edn <<EOF
{:bundle-id "my-stack"
 :description "My awesome stack"
 :deps {...}}
EOF

# 3. Open PR
git add bundles/my-stack.edn
git commit -m "Add my-stack bundle"
git push origin add-my-stack
gh pr create --title "Add my-stack bundle"

# 4. CI automatically:
#    - Validates bundle
#    - Builds .m2
#    - Uploads to Release
#    - Updates bundle registry
```

---

## GitHub Features Used

### 1. Repository Files (Inbox/Outbox)
- **Cost**: Free (up to repo size limits)
- **Limit**: Keep repo under 1 GB (recommended)
- **Pattern**: Use for small manifests only, not tarballs

### 2. GitHub Actions
- **Cost**: Free for public repos, 2,000 min/month for private (Free tier)
- **Limit**: 6 hours per workflow run
- **Pattern**: Build bundles on-demand

### 3. Release Assets
- **Cost**: Free (counted as LFS/bandwidth, but generous)
- **Limit**: 2 GB per file, unlimited total size
- **Pattern**: Perfect for .m2 tarballs (typically 50-500 MB)
- **Public URL**: No auth required for download

### 4. gh CLI
- **Pattern**: Host wrapper uses for artifact download
- **Auth**: `gh auth login` (one-time setup)

---

## Security Model

### Authentication Boundaries

| Component | Needs Auth | Method |
|-----------|-----------|--------|
| Sandboxed agent | ❌ No | None (no network) |
| Host wrapper | ✅ Yes | GitHub PAT or `gh auth login` |
| GitHub Actions | ✅ Yes | Automatic `GITHUB_TOKEN` |
| Bundle download | ❌ No | Public Release URL |

### Public vs Private Repos

**Public repo**:
- ✅ Free Actions minutes
- ✅ Free artifact storage
- ✅ Public bundle downloads
- ⚠️ Bundle manifests visible to world
- ⚠️ Use for open-source deps only

**Private repo**:
- 💰 2,000 min/month (Free tier), then paid
- 💰 500 MB storage (Free tier), then paid
- ⚠️ Release assets still need auth for download
- ✅ Keep proprietary deps private

**Hybrid approach**:
- Public repo for community bundles
- Private repo for org-specific bundles
- Point to same Release storage pattern

---

## Alternative: Artifacts Branch

If you don't want to use Releases, store tarballs in a dedicated Git branch:

**Workflow**:
```bash
# After building m2-job-123.tar.gz
git checkout artifacts  # Orphan branch for binaries
mkdir -p m2-bundles
mv m2-job-123.tar.gz m2-bundles/
git add m2-bundles/m2-job-123.tar.gz
git commit -m "Add bundle job-123"
git push origin artifacts
```

**Public URL**:
```
https://raw.githubusercontent.com/owner/repo/artifacts/m2-bundles/m2-job-123.tar.gz
```

**Pros**:
- Still a public URL
- No separate Release management

**Cons**:
- Git repo grows with binary blobs
- Need to prune old bundles regularly
- Slower than Release CDN

**When to use**: Small bundles (<100 MB), low churn

---

## Cost Estimation

**Scenario**: 10 developers, 5 bundles/day, 200 MB average bundle size

### Public Repo (Recommended)
- **Actions minutes**: Free (unlimited for public)
- **Storage**: Free (Release assets)
- **Bandwidth**: Free (GitHub CDN)
- **Total**: $0/month

### Private Repo
- **Actions minutes**: 5 bundles × 5 min/bundle × 20 days = 500 min/month → Free (under 2,000 limit)
- **Storage**: 5 bundles × 200 MB = 1 GB → $0.24/month (at $0.008/GB/day × 30)
- **Bandwidth**: 10 devs × 200 MB × 5 days = 10 GB → Free (if downloading from Release)
- **Total**: ~$0.25/month

**Compared to GCS**:
- GCS storage: $0.020/GB/month = $0.20/month for 10 GB
- GCS egress: $0.12/GB = $12/month for 100 GB
- **GitHub is cheaper for high download volume**

---

## Recommended Repository Structure

```
m2-bundles/
├── README.md                 # Main docs
├── bundles/                  # Community bundle definitions
│   ├── README.md            # Bundle registry
│   ├── clojure-core.edn
│   ├── web-stack.edn
│   ├── gcs-client.edn
│   └── data-science.edn
├── deps-requests/           # Inbox (transient)
│   └── .gitkeep
├── deps-responses/          # Outbox (transient)
│   └── .gitkeep
├── .github/
│   └── workflows/
│       ├── build-bundle.yml     # Main build workflow
│       ├── validate-pr.yml      # Bundle validation
│       └── cleanup-old.yml      # Prune old requests/responses
├── scripts/
│   ├── request-bundle.sh        # Client-side: create request
│   ├── wait-for-bundle.sh       # Client-side: poll for response
│   ├── download-bundle.sh       # Client-side: fetch and extract
│   └── build-m2-local.sh        # Test bundle builds locally
└── docs/
    ├── architecture.md
    ├── contributing.md
    └── bundle-schema.md
```

---

## Next Steps

See:
- `docs/github-actions-artifacts.md` - Detailed limits and billing
- `docs/bundle-schema.md` - EDN bundle format specification
- `plans/implementation-plan.md` - Step-by-step setup guide
- `examples/` - Sample bundles and wrapper scripts

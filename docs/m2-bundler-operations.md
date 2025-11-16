# M2 Bundler Operations Guide

**Role**: M2 Bundler Service Operator (Responder)

**Responsibility**: Monitor mailbox, build M2 bundles, publish responses

---

## Overview

You are the **M2 Bundler service operator**. Your job is to:

1. Monitor the GCS mailbox bucket for incoming requests from sandboxed Claude agents
2. Build M2 bundles containing Maven/Clojure dependencies
3. Upload bundles to the public bundle bucket
4. Publish responses back to the mailbox so agents know their bundles are ready

Think of yourself as running a **bundle vending machine** - agents put in requests (coins), you build bundles (dispense products), and they download the results.

---

## Architecture (Your Perspective)

```
┌──────────────────────────────────────────┐
│ GCS Mailbox Bucket                       │
│ gs://gene-m2-bundler-mailbox/            │
│                                          │
│ requests/                                │
│   {session-id}/{request-id}.edn  ← READ │
└──────────────────────────────────────────┘
                  ↓
        ┌─────────────────┐
        │ YOU (M2 Bundler) │
        │                  │
        │ 1. Poll requests │
        │ 2. Build bundles │
        │ 3. Upload bundles│
        │ 4. Send responses│
        └─────────────────┘
                  ↓
┌──────────────────────────────────────────┐
│ GCS Bundle Bucket (public-read)          │
│ gs://gene-m2-bundler-bundles/            │
│                                          │
│ bundles/                                 │
│   {bundle-id}-{timestamp}.tar.gz ← WRITE│
└──────────────────────────────────────────┘
                  ↓
┌──────────────────────────────────────────┐
│ GCS Mailbox Bucket                       │
│ gs://gene-m2-bundler-mailbox/            │
│                                          │
│ responses/                               │
│   {session-id}/{request-id}.edn  ← WRITE│
└──────────────────────────────────────────┘
```

---

## Prerequisites

### Required Tools

- `gsutil` (from Google Cloud SDK)
- `gcloud` CLI authenticated
- `make` (for running targets)
- `clojure` CLI (for building bundles)
- `tar`, `gzip` (standard tools)

### Required Access

- Read/write access to `gs://gene-m2-bundler-mailbox/`
- Write access to `gs://gene-m2-bundler-bundles/`
- Your `gcloud` credentials should already have this via project ownership

### Verify Access

```bash
# Check mailbox bucket
gsutil ls gs://gene-m2-bundler-mailbox/

# Check bundle bucket
gsutil ls gs://gene-m2-bundler-bundles/

# If errors, authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

---

## Quick Start

### 1. One-Time Setup

```bash
cd /Users/genekim/src.local/m2builder

# Verify buckets exist (creates if missing)
make setup-buckets

# Test request processing (dry run)
make test-process-request
```

### 2. Start Monitoring

```bash
# Start polling for requests (runs in foreground)
make poll-requests

# Or run in background
make poll-requests-bg

# Check logs
tail -f /tmp/m2-bundler-poll.log
```

### 3. Monitor Activity

```bash
# Dashboard (run in another terminal)
make dashboard

# Or manually check
make list-requests
make list-responses
make list-bundles
```

---

## Core Operations

### Polling for Requests

The polling script continuously checks the mailbox for new requests.

**Manual Check**:
```bash
# List pending requests
gsutil ls gs://gene-m2-bundler-mailbox/requests/**/*.edn

# Process a specific request
./scripts/process-request.sh gs://gene-m2-bundler-mailbox/requests/SESSION_ID/REQUEST_ID.edn
```

**Automated Polling**:
```bash
# Runs continuously, checks every 30 seconds
./scripts/poll-requests.sh
```

**What It Does**:
1. Lists all files in `requests/` folder
2. For each request:
   - Downloads request file
   - Calls `process-request.sh`
   - Moves request to `processed/` folder
3. Sleeps 30 seconds
4. Repeats

### Processing a Request

**Automatic** (via polling):
```bash
# Just let the polling script run
make poll-requests
```

**Manual** (for testing):
```bash
# Process specific request
./scripts/process-request.sh \
  gs://gene-m2-bundler-mailbox/requests/claude-web-123/req-456.edn \
  claude-web-123 \
  req-456
```

**What It Does**:
1. Downloads request EDN file
2. Parses bundle ID from request
3. Looks up bundle definition in `bundles/{bundle-id}.edn`
4. Builds M2 cache with all dependencies
5. Creates tarball
6. Uploads to bundle bucket
7. Generates response with download URL
8. Uploads response to mailbox bucket

### Building Bundles

Bundles are built from `.edn` definitions in `bundles/` directory.

**Available Bundles**:
```bash
# List all bundle definitions
ls bundles/*.edn

# Example bundles:
# - clojure-minimal.edn (5 MB, 3 JARs)
# - web-stack.edn (17 MB, 98 JARs)
# - gcs-client.edn (47 MB, 81 JARs)
# - reddit-scraper-server2.edn (100 MB, ~200 JARs)
```

**Build Manually**:
```bash
# Build specific bundle
./scripts/build-bundle.sh bundles/reddit-scraper-server2.edn

# Output: /tmp/m2-reddit-scraper-server2-{timestamp}.tar.gz
```

**Test Bundle Locally**:
```bash
# Full test (build + verify)
./scripts/test-bundle-local.sh bundles/gcs-client.edn
```

### Publishing Responses

After building a bundle, publish a response so the requester knows it's ready.

**Automatic** (handled by `process-request.sh`):
```bash
# Response automatically generated and uploaded
```

**Manual** (for testing):
```bash
./scripts/send-response.sh \
  claude-web-123 \
  req-456 \
  https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/reddit-scraper-server2-1731700000.tar.gz \
  success
```

**Response Fields**:
- `session-id`: Requester's session ID
- `message-id`: Original request ID
- `status`: `:success`, `:error`, or `:in-progress`
- `bundle-url`: Public download URL
- `bundle-size-mb`: Size in MB
- `artifact-count`: Number of JAR files
- `build-time-seconds`: How long it took

---

## Monitoring & Debugging

### Dashboard View

```bash
# All-in-one status view
make dashboard
```

**Shows**:
- Pending requests count
- Requests processed in last hour
- Recent responses
- Bundle inventory
- Disk space usage

### Manual Monitoring

```bash
# Pending requests
gsutil ls gs://gene-m2-bundler-mailbox/requests/**/*.edn | wc -l

# Recent responses
gsutil ls -l gs://gene-m2-bundler-mailbox/responses/**/*.edn | head -10

# Bundles published today
gsutil ls -lh gs://gene-m2-bundler-bundles/bundles/*.tar.gz | grep "$(date +%Y-%m-%d)"

# Total bundle storage
gsutil du -sh gs://gene-m2-bundler-bundles/bundles/
```

### Logs

```bash
# Polling logs
tail -f /tmp/m2-bundler-poll.log

# Last 100 lines
tail -100 /tmp/m2-bundler-poll.log

# Search for errors
grep ERROR /tmp/m2-bundler-poll.log
```

### Troubleshooting

#### No Requests Appearing

**Check mailbox bucket**:
```bash
gsutil ls gs://gene-m2-bundler-mailbox/requests/
```

If empty, either:
1. No agents have submitted requests yet
2. Requests are being processed faster than you're checking
3. Check `processed/` folder for completed requests

**Test with mock request**:
```bash
# Create test request
./scripts/create-test-request.sh test-session test-request-001 clojure-minimal

# Should appear in mailbox
gsutil ls gs://gene-m2-bundler-mailbox/requests/test-session/
```

#### Bundle Build Fails

**Check bundle definition**:
```bash
# Validate EDN syntax
clojure -e "(require 'clojure.edn) (clojure.edn/read-string (slurp \"bundles/reddit-scraper-server2.edn\"))"
```

**Check dependencies exist**:
```bash
# Try building locally
./scripts/build-bundle.sh bundles/reddit-scraper-server2.edn

# If fails, check error messages
# Common issues:
# - Missing dependency in Maven Central
# - Typo in group/artifact ID
# - Network issues
```

**Check disk space**:
```bash
df -h /tmp
# M2 bundles need ~2-3 GB temp space
```

#### Response Not Delivered

**Check response was written**:
```bash
gsutil ls gs://gene-m2-bundler-mailbox/responses/SESSION_ID/REQUEST_ID.edn
```

**Check response permissions**:
```bash
# Response files should be publicly readable so agents can download
gsutil acl get gs://gene-m2-bundler-mailbox/responses/SESSION_ID/REQUEST_ID.edn
```

**Manually fix permissions** (if needed):
```bash
gsutil acl ch -u AllUsers:R gs://gene-m2-bundler-mailbox/responses/SESSION_ID/REQUEST_ID.edn
```

---

## Maintenance Tasks

### Clean Up Old Files

**Archive old requests** (after 30 days):
```bash
# List old processed requests
gsutil ls gs://gene-m2-bundler-mailbox/processed/**/*.edn

# Delete processed requests older than 30 days
gsutil -m rm gs://gene-m2-bundler-mailbox/processed/**/*.edn

# Or set lifecycle rule (one-time setup)
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {
        "age": 30,
        "matchesPrefix": ["processed/"]
      }
    }]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://gene-m2-bundler-mailbox/
```

**Clean old bundles** (keep last 5 versions):
```bash
# List bundles for specific bundle-id
gsutil ls gs://gene-m2-bundler-bundles/bundles/reddit-scraper-server2-*.tar.gz

# Delete old versions (keep last 5)
gsutil ls gs://gene-m2-bundler-bundles/bundles/reddit-scraper-server2-*.tar.gz | head -n -5 | xargs -r gsutil rm
```

### Update Bundle Definitions

**Add new bundle**:
```bash
# Create new bundle definition
cat > bundles/my-project.edn <<EOF
{:schema-version "1.0.0"
 :bundle-id "my-project"
 :version "1.0.0"
 :description "My project dependencies"
 :deps {org.clojure/clojure {:mvn/version "1.11.3"}}}
EOF

# Test it
./scripts/build-bundle.sh bundles/my-project.edn

# Commit to repo
git add bundles/my-project.edn
git commit -m "Add my-project bundle"
git push
```

**Update existing bundle**:
```bash
# Edit bundle definition
vim bundles/reddit-scraper-server2.edn

# Test changes
./scripts/build-bundle.sh bundles/reddit-scraper-server2.edn

# Commit
git add bundles/reddit-scraper-server2.edn
git commit -m "Update reddit-scraper-server2 deps"
git push
```

---

## Advanced Operations

### Priority Queue

Process high-priority requests first:

```bash
# Check for high-priority requests
gsutil ls gs://gene-m2-bundler-mailbox/requests/**/*.edn | while read req; do
  gsutil cat "$req" | grep ':priority :high' && echo "HIGH: $req"
done
```

### Parallel Processing

Process multiple requests concurrently:

```bash
# Process up to 3 requests in parallel
gsutil ls gs://gene-m2-bundler-mailbox/requests/**/*.edn | head -3 | xargs -P 3 -I {} ./scripts/process-request.sh {}
```

### Bundle Caching

Avoid rebuilding identical bundles:

```bash
# Check if bundle already exists
BUNDLE_ID="reddit-scraper-server2"
LATEST=$(gsutil ls "gs://gene-m2-bundler-bundles/bundles/${BUNDLE_ID}-*.tar.gz" | tail -1)

if [ -n "$LATEST" ]; then
  echo "Reusing existing bundle: $LATEST"
  # Send response with existing bundle URL
else
  echo "Building new bundle..."
  ./scripts/build-bundle.sh "bundles/${BUNDLE_ID}.edn"
fi
```

### Metrics Collection

Track request volume and build times:

```bash
# Count requests processed today
gsutil ls gs://gene-m2-bundler-mailbox/processed/**/*.edn | \
  xargs gsutil stat | \
  grep "Time created:" | \
  grep "$(date +%Y-%m-%d)" | \
  wc -l

# Average build time (from responses)
gsutil ls gs://gene-m2-bundler-mailbox/responses/**/*.edn | \
  xargs gsutil cat | \
  grep ':build-time-seconds' | \
  awk '{sum+=$2; count++} END {print "Avg:", sum/count, "seconds"}'
```

---

## Integration with CI/CD

### GitHub Actions (Optional)

Run M2 Bundler as a GitHub Action instead of locally:

```yaml
# .github/workflows/m2-bundler-service.yml
name: M2 Bundler Service

on:
  schedule:
    - cron: '*/5 * * * *'  # Every 5 minutes
  workflow_dispatch:

jobs:
  poll-and-process:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to GCS
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SERVICE_ACCOUNT_KEY }}

      - name: Poll for requests
        run: ./scripts/poll-requests.sh --once
```

### Cloud Run (Serverless)

Deploy as a Cloud Run service:

```bash
# Build container
docker build -t gcr.io/PROJECT_ID/m2-bundler-service -f Dockerfile.service .

# Deploy
gcloud run deploy m2-bundler-service \
  --image=gcr.io/PROJECT_ID/m2-bundler-service \
  --region=us-central1 \
  --no-allow-unauthenticated

# Trigger via Cloud Scheduler
gcloud scheduler jobs create http poll-m2-requests \
  --schedule="*/5 * * * *" \
  --uri="https://m2-bundler-service-xxxxx.run.app/poll"
```

---

## Security Best Practices

### Credential Management

- Never commit GCS credentials to repo
- Use service accounts for automation
- Rotate service account keys quarterly
- Use workload identity for GKE/Cloud Run

### Access Control

```bash
# Verify bucket permissions
gsutil iam get gs://gene-m2-bundler-mailbox/
gsutil iam get gs://gene-m2-bundler-bundles/

# Mailbox: Should be private (only you can write)
# Bundles: Should be public-read (agents can download)
```

### Request Validation

Always validate request contents before processing:

```bash
# In process-request.sh
# Check for malicious paths
if echo "$BUNDLE_ID" | grep -q '\.\.'; then
  echo "ERROR: Invalid bundle ID (path traversal attempt)"
  exit 1
fi

# Check bundle definition exists
if [ ! -f "bundles/${BUNDLE_ID}.edn" ]; then
  echo "ERROR: Unknown bundle ID: $BUNDLE_ID"
  exit 1
fi
```

---

## FAQ

### Q: How long does a bundle build take?

**A**: Depends on bundle size:
- `clojure-minimal`: ~3 seconds
- `web-stack`: ~3 seconds
- `gcs-client`: ~12 seconds
- `reddit-scraper-server2`: ~30-60 seconds

### Q: Can I process multiple requests in parallel?

**A**: Yes! Use `xargs -P N` to process N requests concurrently. Each request builds to a unique temp directory, so there are no conflicts.

### Q: What happens if a build fails?

**A**: Send an error response so the requester knows:

```bash
./scripts/send-response.sh SESSION_ID REQUEST_ID "" error "Build failed: dependency not found"
```

### Q: How much disk space do I need?

**A**: ~5-10 GB free in `/tmp` for building large bundles. Each bundle uses ~2-3 GB during build, then compresses to ~50-500 MB.

### Q: Can requests specify custom dependencies?

**A**: Yes! If the request includes a `:deps-file` field, use that instead of the standard bundle definition.

### Q: How do I know if a request is from a trusted source?

**A**: All requests come through the authenticated HTTP gateway, so if a request is in the bucket, it passed authentication. The `:from` field identifies the session, but sessions can be spoofed. Trust is based on gateway authentication.

---

## Appendix: Request/Response Format

### Request Format

```clojure
{:schema-version "1.0.0"
 :timestamp "2025-11-15T17:10:00Z"
 :from "claude-code-web-01E7aVp"
 :session-id "claude-web-01E7aVp"
 :message-id "req-1731700000"
 :type :request
 :payload {:bundle-id "reddit-scraper-server2"
           :deps-file nil              ; Optional
           :aliases [:dev :test]       ; Optional
           :priority :normal}}         ; :low, :normal, :high
```

### Response Format

```clojure
{:schema-version "1.0.0"
 :timestamp "2025-11-15T17:12:00Z"
 :from "m2-bundler-service"
 :session-id "claude-web-01E7aVp"
 :message-id "req-1731700000"
 :type :response
 :status :success  ; :success, :error, :in-progress
 :payload {:bundle-url "https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/reddit-scraper-server2-1731700000.tar.gz"
           :bundle-size-mb 47
           :artifact-count 81
           :build-time-seconds 12
           :sha256 "abc123..."
           :expires-at "2025-12-15T17:12:00Z"}
 :error nil}       ; Only if status = :error
```

---

## Support

**Issues**: https://github.com/realgenekim/m2builder/issues

**Contact**: @realgenekim

**Logs**: `/tmp/m2-bundler-poll.log`

---

**You're all set!** Start with `make poll-requests` and monitor `make dashboard`. 🚀

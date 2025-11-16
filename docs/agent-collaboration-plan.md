# M2 Bundler ↔ Sandboxed Claude Agent Collaboration Plan

**Goal**: Enable bidirectional communication between sandboxed Claude Code agents and the M2 Bundler service within 30 minutes.

**Timeline Target**: 2025-11-15 17:40 (30 minutes from now)

---

## Executive Summary

### The Problem
Sandboxed Claude Code agents need Maven/Clojure dependencies but:
- Cannot access Maven Central directly (network restrictions)
- Cannot use `gcloud` CLI (not installed in sandbox)
- Can only use `curl` for HTTP requests

### The Solution
**Two-bucket architecture with HTTP gateway**:

1. **Mailbox Bucket** (`gene-m2-bundler-mailbox`): Request/response messages
   - Sandboxed agents write via HTTP gateway (Flask service)
   - M2 Bundler reads/writes via `gsutil` (full access)

2. **Bundle Bucket** (`gene-m2-bundler-bundles`): M2 dependency tarballs
   - Public-read, so sandboxed agents can download via `curl`
   - M2 Bundler writes via `gsutil`

### Key Components

```
┌─────────────────────────────────────────────────────────┐
│ Sandboxed Claude Code Agent (Requester)                │
│ - Can: curl (HTTP only)                                │
│ - Cannot: gcloud, gsutil, direct GCS access            │
└────────────┬────────────────────────────────────────────┘
             │
             │ 1. POST request via HTTP Basic Auth
             ↓
┌─────────────────────────────────────────────────────────┐
│ Python Flask Gateway (Cloud Run)                       │
│ - Authenticates requests                               │
│ - Writes to GCS mailbox bucket                         │
│ - Public HTTPS endpoint                                │
└────────────┬────────────────────────────────────────────┘
             │
             │ 2. Write to mailbox bucket
             ↓
┌─────────────────────────────────────────────────────────┐
│ GCS Mailbox Bucket (gene-m2-bundler-mailbox)           │
│ requests/session-{id}/{request-id}.edn                 │
│ responses/session-{id}/{request-id}.edn                │
└────────────┬────────────────────────────────────────────┘
             │
             │ 3. Poll for new requests
             ↓
┌─────────────────────────────────────────────────────────┐
│ M2 Bundler Service (Responder)                         │
│ - Polls mailbox bucket for new requests               │
│ - Builds M2 bundles                                    │
│ - Uploads bundles to bundle bucket                     │
│ - Writes responses to mailbox bucket                   │
└────────────┬────────────────────────────────────────────┘
             │
             │ 4. Upload bundle
             ↓
┌─────────────────────────────────────────────────────────┐
│ GCS Bundle Bucket (gene-m2-bundler-bundles)            │
│ bundles/reddit-scraper-server2-{timestamp}.tar.gz      │
│ (Public-read, so curl can download directly)           │
└────────────┬────────────────────────────────────────────┘
             │
             │ 5. Download bundle via curl
             ↓
┌─────────────────────────────────────────────────────────┐
│ Sandboxed Claude Code Agent                            │
│ - Downloads bundle                                     │
│ - Extracts to ~/.m2-cache/                             │
│ - Uses for project builds                              │
└─────────────────────────────────────────────────────────┘
```

---

## Architecture Details

### 1. Mailbox Bucket Structure

**Bucket**: `gs://gene-m2-bundler-mailbox/`

**Layout**:
```
requests/
  {session-id}/
    {request-id}.edn     # Claude agent requests
responses/
  {session-id}/
    {request-id}.edn     # M2 Bundler responses
processed/
  {session-id}/
    {request-id}.edn     # Archived after completion
```

**Session ID**: Unique identifier for each Claude agent session (e.g., `claude-web-01E7aVp`)

**Request ID**: Unique identifier for each request (e.g., `req-1731700000`)

### 2. Bundle Bucket Structure

**Bucket**: `gs://gene-m2-bundler-bundles/` (public-read)

**Layout**:
```
bundles/
  reddit-scraper-server2-1731700000.tar.gz
  web-stack-1731700123.tar.gz
  gcs-client-1731700456.tar.gz
metadata/
  reddit-scraper-server2-1731700000.json   # Build metadata
```

### 3. Message Protocol

#### Request Format (`{request-id}.edn`)

```clojure
{:schema-version "1.0.0"
 :timestamp "2025-11-15T17:10:00Z"
 :from "claude-code-web-01E7aVp"
 :session-id "claude-web-01E7aVp"
 :message-id "req-1731700000"
 :type :request
 :payload {:bundle-id "reddit-scraper-server2"
           :deps-file nil              ; Optional: custom deps.edn
           :aliases [:dev :test]       ; Optional: specific aliases
           :priority :normal}}         ; Optional: :low, :normal, :high
```

#### Response Format (`{request-id}.edn`)

```clojure
{:schema-version "1.0.0"
 :timestamp "2025-11-15T17:12:00Z"
 :from "m2-bundler-service"
 :session-id "claude-web-01E7aVp"
 :message-id "req-1731700000"
 :type :response
 :status :success  ; or :error, :in-progress
 :payload {:bundle-url "https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/reddit-scraper-server2-1731700000.tar.gz"
           :bundle-size-mb 47
           :artifact-count 81
           :build-time-seconds 12
           :sha256 "abc123..."
           :expires-at "2025-12-15T17:12:00Z"}  ; 30 days
 :error nil}       ; Only if status = :error
```

---

## Implementation Plan (30 Minutes)

### Phase 1: Infrastructure Setup (10 min)

**Tasks**:
1. ✅ Create/verify GCS buckets
2. ✅ Deploy Python Flask gateway to Cloud Run
3. ✅ Generate authentication credentials
4. ✅ Test gateway health endpoint

**Commands**:
```bash
# 1. Create buckets
gsutil mb -l us-central1 gs://gene-m2-bundler-mailbox/
gsutil mb -l us-central1 gs://gene-m2-bundler-bundles/

# 2. Set bundle bucket to public-read
gsutil iam ch allUsers:objectViewer gs://gene-m2-bundler-bundles/

# 3. Deploy gateway (see gateway/deploy.sh)
cd gateway
export BASIC_AUTH_PASS=$(openssl rand -base64 32)
./deploy.sh

# 4. Save credentials
echo "Gateway URL: https://gcs-gateway-xxxxx.run.app" > .credentials
echo "User: claude" >> .credentials
echo "Pass: ${BASIC_AUTH_PASS}" >> .credentials
```

### Phase 2: M2 Bundler Service (10 min)

**Tasks**:
1. ✅ Create polling script for mailbox bucket
2. ✅ Create bundle builder script
3. ✅ Create response writer script
4. ✅ Test with mock request

**Files to Create**:
- `scripts/poll-requests.sh` - Monitor mailbox for new requests
- `scripts/process-request.sh` - Build bundle from request
- `scripts/send-response.sh` - Write response to mailbox

**Workflow**:
```bash
# In M2 Bundler repo
make poll-requests   # Runs continuously, checks every 30s
```

### Phase 3: Sandboxed Agent Scripts (10 min)

**Tasks**:
1. ✅ Create request submission script
2. ✅ Create response polling script
3. ✅ Create bundle download script
4. ✅ Test end-to-end workflow

**Files to Create**:
- `claude-agent/request-bundle.sh` - Submit request via gateway
- `claude-agent/check-status.sh` - Poll for response
- `claude-agent/download-bundle.sh` - Download and extract bundle
- `claude-agent/README.md` - Instructions for Claude agents

**Workflow**:
```bash
# In sandboxed Claude Code session
./request-bundle.sh reddit-scraper-server2
# Wait ~60 seconds
./check-status.sh req-1731700000
# Download bundle
./download-bundle.sh https://storage.googleapis.com/.../bundle.tar.gz
```

---

## Detailed Component Specs

### M2 Bundler Service (Responder)

**Location**: `/Users/genekim/src.local/m2builder/`

**Role**: Monitor mailbox, build bundles, respond to requests

**Key Scripts**:

#### `scripts/poll-requests.sh`
```bash
#!/bin/bash
# Poll GCS mailbox for new requests

MAILBOX_BUCKET="gene-m2-bundler-mailbox"
CHECK_INTERVAL=30  # seconds

while true; do
  # List unprocessed requests
  gsutil ls "gs://${MAILBOX_BUCKET}/requests/**/*.edn" 2>/dev/null | while read -r request_file; do
    REQUEST_ID=$(basename "$request_file" .edn)
    SESSION_ID=$(basename "$(dirname "$request_file")")

    echo "[$(date)] Processing: ${SESSION_ID}/${REQUEST_ID}"

    # Process request
    ./scripts/process-request.sh "$request_file" "$SESSION_ID" "$REQUEST_ID"

    # Move to processed
    gsutil mv "$request_file" "gs://${MAILBOX_BUCKET}/processed/${SESSION_ID}/${REQUEST_ID}.edn"
  done

  sleep "$CHECK_INTERVAL"
done
```

#### `scripts/process-request.sh`
```bash
#!/bin/bash
# Build M2 bundle from request

REQUEST_FILE=$1
SESSION_ID=$2
REQUEST_ID=$3

# Download request
gsutil cp "$REQUEST_FILE" "/tmp/${REQUEST_ID}.edn"

# Parse request (extract bundle-id)
BUNDLE_ID=$(grep ':bundle-id' "/tmp/${REQUEST_ID}.edn" | awk -F'"' '{print $2}')

# Build bundle
./scripts/build-bundle.sh "bundles/${BUNDLE_ID}.edn"

# Upload to bundle bucket
TIMESTAMP=$(date +%s)
BUNDLE_FILE="/tmp/m2-${BUNDLE_ID}-${TIMESTAMP}.tar.gz"
gsutil cp "$BUNDLE_FILE" "gs://gene-m2-bundler-bundles/bundles/"

# Generate response
BUNDLE_URL="https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/$(basename "$BUNDLE_FILE")"
./scripts/send-response.sh "$SESSION_ID" "$REQUEST_ID" "$BUNDLE_URL"
```

#### `scripts/send-response.sh`
```bash
#!/bin/bash
# Write response to mailbox

SESSION_ID=$1
REQUEST_ID=$2
BUNDLE_URL=$3

cat > "/tmp/response-${REQUEST_ID}.edn" <<EOF
{:schema-version "1.0.0"
 :timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
 :from "m2-bundler-service"
 :session-id "${SESSION_ID}"
 :message-id "${REQUEST_ID}"
 :type :response
 :status :success
 :payload {:bundle-url "${BUNDLE_URL}"}}
EOF

# Upload response
gsutil cp "/tmp/response-${REQUEST_ID}.edn" \
  "gs://gene-m2-bundler-mailbox/responses/${SESSION_ID}/${REQUEST_ID}.edn"
```

### Sandboxed Claude Agent (Requester)

**Location**: `docs/claude-agent/` (documentation and scripts for Claude to use)

**Role**: Submit requests, poll for responses, download bundles

**Key Scripts**:

#### `claude-agent/request-bundle.sh`
```bash
#!/bin/bash
# Submit bundle request via HTTP gateway

BUNDLE_ID=${1:-"reddit-scraper-server2"}
SESSION_ID="claude-web-$(date +%s)"
REQUEST_ID="req-$(date +%s)"

# Load credentials
source .env

# Create request
REQUEST_CONTENT="{:schema-version \"1.0.0\" :timestamp \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" :from \"${SESSION_ID}\" :session-id \"${SESSION_ID}\" :message-id \"${REQUEST_ID}\" :type :request :payload {:bundle-id \"${BUNDLE_ID}\"}}"

# Submit via gateway
curl -u "${GCS_GATEWAY_USER}:${GCS_GATEWAY_PASS}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"path\":\"requests/${SESSION_ID}/${REQUEST_ID}.edn\",\"content\":\"${REQUEST_CONTENT}\"}" \
  "${GCS_GATEWAY_URL}/upload"

echo "✅ Request submitted: ${REQUEST_ID}"
echo "   Session: ${SESSION_ID}"
echo "   Bundle: ${BUNDLE_ID}"
echo ""
echo "Check status with: ./check-status.sh ${SESSION_ID} ${REQUEST_ID}"
```

#### `claude-agent/check-status.sh`
```bash
#!/bin/bash
# Poll for response

SESSION_ID=$1
REQUEST_ID=$2

RESPONSE_URL="https://storage.googleapis.com/gene-m2-bundler-mailbox/responses/${SESSION_ID}/${REQUEST_ID}.edn"

# Try to download response (public-read)
if curl -f -s "$RESPONSE_URL" -o "/tmp/response.edn"; then
  echo "✅ Response received!"
  cat "/tmp/response.edn"

  # Extract bundle URL
  BUNDLE_URL=$(grep ':bundle-url' "/tmp/response.edn" | awk -F'"' '{print $2}')
  echo ""
  echo "Download with: ./download-bundle.sh ${BUNDLE_URL}"
else
  echo "⏳ Still processing... (check again in 30s)"
fi
```

#### `claude-agent/download-bundle.sh`
```bash
#!/bin/bash
# Download and extract M2 bundle

BUNDLE_URL=$1
DEST_DIR="${HOME}/.m2-cache"

mkdir -p "$DEST_DIR"

# Download
BUNDLE_FILE="/tmp/$(basename "$BUNDLE_URL")"
curl -L -o "$BUNDLE_FILE" "$BUNDLE_URL"

# Extract
tar -xzf "$BUNDLE_FILE" -C "$DEST_DIR"

echo "✅ Bundle extracted to: ${DEST_DIR}"
echo ""
echo "Use with: clojure -Sdeps '{:mvn/local-repo \"${DEST_DIR}\"}' ..."
```

---

## Security Model

### Authentication & Authorization

1. **Sandboxed Agents → Gateway**: HTTP Basic Auth
   - Username: `claude`
   - Password: 32-character random string
   - Transmitted over HTTPS only

2. **Gateway → GCS**: Service Account
   - Has `roles/storage.objectCreator` on mailbox bucket
   - No other permissions

3. **M2 Bundler → GCS**: Full Access
   - Uses developer's `gcloud` credentials
   - Can read/write both buckets

4. **Bundle Downloads**: Public Read
   - Bundle bucket is `allUsers:objectViewer`
   - Anyone with URL can download (intentional)

### Security Boundaries

```
┌─────────────────┐
│ Sandboxed Agent │  ← Limited: curl only
└────────┬────────┘
         │ HTTPS + Basic Auth
         ↓
┌─────────────────┐
│  Flask Gateway  │  ← Authenticated: validates requests
└────────┬────────┘
         │ Service Account (write-only)
         ↓
┌─────────────────┐
│ Mailbox Bucket  │  ← Private (except responses = public-read)
└─────────────────┘

┌─────────────────┐
│  M2 Bundler     │  ← Trusted: full GCS access
└────────┬────────┘
         │ Developer credentials
         ↓
┌─────────────────┐
│ Bundle Bucket   │  ← Public-read (bundles are not secrets)
└─────────────────┘
```

---

## Testing Plan

### End-to-End Test (5 minutes)

**Goal**: Verify complete workflow from request to download

**Steps**:

1. **Start M2 Bundler polling**:
   ```bash
   cd /Users/genekim/src.local/m2builder
   make poll-requests &
   ```

2. **Submit request from "sandbox"** (simulate Claude agent):
   ```bash
   cd /Users/genekim/src.local/m2builder/claude-agent
   ./request-bundle.sh reddit-scraper-server2
   # Note SESSION_ID and REQUEST_ID from output
   ```

3. **Wait for processing** (~60 seconds):
   ```bash
   watch -n 5 "./check-status.sh SESSION_ID REQUEST_ID"
   ```

4. **Download bundle**:
   ```bash
   ./download-bundle.sh BUNDLE_URL
   ```

5. **Verify bundle**:
   ```bash
   ls -lh ~/.m2-cache/
   clojure -Sdeps '{:mvn/local-repo "'${HOME}'/.m2-cache"}' -Spath
   ```

**Success Criteria**:
- ✅ Request appears in mailbox bucket
- ✅ M2 Bundler detects and processes request
- ✅ Bundle built and uploaded to bundle bucket
- ✅ Response written to mailbox bucket
- ✅ Claude agent downloads and extracts bundle
- ✅ Bundle contains expected JARs

---

## Monitoring & Operations

### M2 Bundler Operator View

**Dashboard** (manual checks):
```bash
# Active requests
gsutil ls gs://gene-m2-bundler-mailbox/requests/**/*.edn

# Recent responses
gsutil ls -l gs://gene-m2-bundler-mailbox/responses/**/*.edn | head -10

# Bundle inventory
gsutil ls -lh gs://gene-m2-bundler-bundles/bundles/*.tar.gz

# Gateway health
curl https://gcs-gateway-xxxxx.run.app/health
```

**Logs**:
```bash
# Gateway logs
gcloud run services logs read gcs-upload-gateway --limit=50

# Local polling logs
tail -f /tmp/m2-bundler-poll.log
```

### Claude Agent View

**Self-Service Commands**:
```bash
# Submit request
./request-bundle.sh reddit-scraper-server2

# Check status
./check-status.sh SESSION_ID REQUEST_ID

# List available bundles
curl https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/
```

---

## Cost Estimates

### Monthly Costs (assuming 100 requests/month)

| Component | Usage | Cost |
|-----------|-------|------|
| Cloud Run Gateway | 100 requests, ~1 sec each | FREE (within free tier) |
| GCS Mailbox Bucket | 100 files × 2 KB × 2 (req+resp) | FREE (~$0.00) |
| GCS Bundle Bucket | 10 bundles × 50 MB each | $0.01 (storage) |
| GCS Egress | 100 downloads × 50 MB | FREE (within free tier) |
| **Total** | | **~$0.01/month** |

**Real-world estimate**: $1-5/month depending on bundle sizes and retention policies

---

## Next Steps

### Immediate (Next 30 minutes)

1. ✅ Create GCS buckets
2. ✅ Deploy Flask gateway
3. ✅ Create M2 Bundler polling/processing scripts
4. ✅ Create Claude agent helper scripts
5. ✅ Run end-to-end test

### Short-term (Next session)

1. 📝 Add error handling and retries
2. 📝 Add bundle caching (avoid rebuilding same bundle)
3. 📝 Add request prioritization
4. 📝 Add expiration/cleanup for old bundles

### Long-term (Future)

1. 🔮 WebSocket streaming for real-time updates
2. 🔮 Bundle composition (combine multiple bundles)
3. 🔮 Metrics dashboard (request volume, build times)
4. 🔮 Automated testing of bundles before publishing

---

## Success Metrics

**30-Minute Goal**: ✅ Complete bidirectional communication

- [ ] Sandboxed Claude agent submits request via HTTP
- [ ] M2 Bundler detects request
- [ ] M2 Bundler builds bundle
- [ ] M2 Bundler publishes response
- [ ] Sandboxed Claude agent downloads bundle
- [ ] Bundle successfully used in project

**Total Expected Time**: ~25 minutes (5 minutes buffer)

---

## Documentation Structure

### For M2 Bundler Operators

- `docs/m2-bundler-operations.md` - How to run the service
- `scripts/poll-requests.sh` - Request monitoring
- `scripts/process-request.sh` - Bundle building
- `scripts/send-response.sh` - Response publishing

### For Sandboxed Claude Agents

- `docs/claude-agent/README.md` - Overview and quickstart
- `claude-agent/request-bundle.sh` - Submit request
- `claude-agent/check-status.sh` - Check status
- `claude-agent/download-bundle.sh` - Get bundle
- `claude-agent/.env.example` - Credentials template

---

## Conclusion

This architecture provides:

✅ **Secure**: Authentication, authorization, no public-write buckets
✅ **Simple**: Curl-based, no special tools required in sandbox
✅ **Scalable**: Serverless gateway, polling service can run anywhere
✅ **Cheap**: <$5/month for hundreds of requests
✅ **Reliable**: GCS durability, Cloud Run availability
✅ **Debuggable**: All messages stored in GCS, easy to inspect

**Let's build it!** 🚀

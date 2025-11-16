# Claude Agent Guide - M2 Bundle Requester

**Role**: Sandboxed Claude Code Agent (Requester)

**Capability**: Request M2 Maven/Clojure dependency bundles using only `curl`

---

## Overview

You are a **sandboxed Claude Code agent** working on a Clojure project. You need Maven dependencies but:

❌ Cannot access Maven Central directly (network restricted)
❌ Cannot use `gcloud` or `gsutil` (not installed)
✅ **CAN use `curl`** (HTTP requests only)

This guide shows you how to request pre-built M2 dependency bundles from the M2 Bundler service and download them to your sandbox.

---

## Quick Start (3 Steps)

### 1. Get Credentials

Your human operator will provide three values:

```bash
export GCS_GATEWAY_URL="https://gcs-upload-gateway-xxxxx.run.app"
export GCS_GATEWAY_USER="claude"
export GCS_GATEWAY_PASS="your-secret-password-here"
```

Save these to `.env`:

```bash
cat > .env <<EOF
GCS_GATEWAY_URL="${GCS_GATEWAY_URL}"
GCS_GATEWAY_USER="${GCS_GATEWAY_USER}"
GCS_GATEWAY_PASS="${GCS_GATEWAY_PASS}"
EOF
```

### 2. Request a Bundle

```bash
# Request reddit-scraper-server2 bundle
./request-bundle.sh reddit-scraper-server2

# Output shows SESSION_ID and REQUEST_ID
# Example:
#   ✅ Request submitted: req-1731700000
#   Session: claude-web-1731700000
#   Bundle: reddit-scraper-server2
```

### 3. Wait and Download

```bash
# Check status (repeat every 30s until ready)
./check-status.sh claude-web-1731700000 req-1731700000

# When ready, download bundle
./download-bundle.sh https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/reddit-scraper-server2-1731700000.tar.gz

# Use bundle
clojure -Sdeps '{:mvn/local-repo "'${HOME}'/.m2-cache"}' -M:dev -m server2.core
```

**Total time**: ~60-90 seconds from request to ready

---

## Available Bundles

| Bundle ID | Description | Size | JARs | Build Time |
|-----------|-------------|------|------|------------|
| `clojure-minimal` | Clojure core only | 5 MB | 3 | ~3s |
| `web-stack` | Ring + Reitit + Muuntaja | 17 MB | 98 | ~3s |
| `gcs-client` | Google Cloud Storage | 47 MB | 81 | ~12s |
| `reddit-scraper-server2` | Full server2 stack | 100 MB | ~200 | ~60s |

### How to Choose

**Starting a new project?** → `clojure-minimal`
**Building a web service?** → `web-stack`
**Need GCS access?** → `gcs-client`
**Working on reddit-scraper?** → `reddit-scraper-server2`

**Custom dependencies?** See "Custom Bundle Requests" below.

---

## Detailed Workflow

### Step 1: Request Bundle

**Script**: `./request-bundle.sh`

**Usage**:
```bash
./request-bundle.sh BUNDLE_ID
```

**Example**:
```bash
./request-bundle.sh gcs-client
```

**What it does**:
1. Generates unique session ID and request ID
2. Creates EDN request message
3. Uploads request to M2 Bundler mailbox via HTTP gateway
4. Prints request details

**Output**:
```
✅ Request submitted: req-1731700123
   Session: claude-web-1731700000
   Bundle: gcs-client

Check status with: ./check-status.sh claude-web-1731700000 req-1731700123
```

**Save these values!** You'll need SESSION_ID and REQUEST_ID to check status.

### Step 2: Check Status

**Script**: `./check-status.sh`

**Usage**:
```bash
./check-status.sh SESSION_ID REQUEST_ID
```

**Example**:
```bash
./check-status.sh claude-web-1731700000 req-1731700123
```

**Output (still processing)**:
```
⏳ Still processing... (check again in 30s)
```

**Output (ready)**:
```
✅ Response received!
{:schema-version "1.0.0"
 :status :success
 :payload {:bundle-url "https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/gcs-client-1731700200.tar.gz"
           :bundle-size-mb 47
           :artifact-count 81}}

Download with: ./download-bundle.sh https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/gcs-client-1731700200.tar.gz
```

**Polling Strategy**:
```bash
# Poll every 30 seconds until ready
while ! ./check-status.sh SESSION_ID REQUEST_ID | grep -q "✅ Response received"; do
  sleep 30
done
```

### Step 3: Download Bundle

**Script**: `./download-bundle.sh`

**Usage**:
```bash
./download-bundle.sh BUNDLE_URL
```

**Example**:
```bash
./download-bundle.sh https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/gcs-client-1731700200.tar.gz
```

**What it does**:
1. Downloads tarball to `/tmp/`
2. Extracts to `~/.m2-cache/`
3. Prints usage instructions

**Output**:
```
Downloading bundle...
Extracting to /Users/claude/.m2-cache...
✅ Bundle extracted to: /Users/claude/.m2-cache

Use with: clojure -Sdeps '{:mvn/local-repo "/Users/claude/.m2-cache"}' ...
```

### Step 4: Use Bundle

**Configure Clojure to use the cache**:

**Option A: Environment variable** (recommended for sandboxes):
```bash
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'${HOME}'/.m2-cache"}' > $CLJ_CONFIG/deps.edn
```

**Option B: Per-command**:
```bash
clojure -Sdeps '{:mvn/local-repo "'${HOME}'/.m2-cache"}' -M:dev -m my.app
```

**Option C: Global config** (persists):
```bash
mkdir -p ~/.clojure
echo '{:mvn/local-repo "'${HOME}'/.m2-cache"}' > ~/.clojure/deps.edn
```

**Verify it works**:
```bash
# Check classpath includes cache
clojure -Spath | grep '\.m2-cache'

# Should see paths like:
# /Users/claude/.m2-cache/org/clojure/clojure/1.11.3/clojure-1.11.3.jar
```

---

## Advanced Usage

### Custom Bundle Requests

If you need dependencies not in a predefined bundle, create a custom request:

**1. Create custom deps.edn**:
```bash
cat > /tmp/custom-deps.edn <<EOF
{:deps {org.clojure/clojure {:mvn/version "1.11.3"}
        my-org/my-lib {:mvn/version "1.2.3"}}}
EOF
```

**2. Request with custom deps**:
```bash
# Edit request-bundle.sh to include :deps-file field
# Or use request-custom-bundle.sh (if available)
```

**3. M2 Bundler will build from your custom deps**

### Multiple Bundles

Working on multiple projects? Request each separately:

```bash
# Project 1
./request-bundle.sh web-stack
# Wait for response, download to ~/.m2-cache-web/

# Project 2
./request-bundle.sh gcs-client
# Download to ~/.m2-cache-gcs/

# Use different caches per project
clojure -Sdeps '{:mvn/local-repo "'${HOME}'/.m2-cache-web"}' ...
clojure -Sdeps '{:mvn/local-repo "'${HOME}'/.m2-cache-gcs"}' ...
```

### Reusing Bundles

Bundles are cached, so if you request the same bundle twice:

1. First request: Builds bundle (~60s)
2. Second request: Returns existing bundle (~5s)

**Tip**: If your project's `deps.edn` hasn't changed, reuse the same bundle!

---

## Troubleshooting

### Authentication Failed (401)

**Problem**: Credentials are wrong or expired.

**Solution**:
```bash
# Check credentials
cat .env

# If wrong, update from operator
export GCS_GATEWAY_PASS="new-password"
echo "GCS_GATEWAY_PASS=${GCS_GATEWAY_PASS}" >> .env
```

### Request Submitted But No Response

**Problem**: M2 Bundler might be offline or request is still processing.

**Check**:
```bash
# Test gateway health
curl "${GCS_GATEWAY_URL}/health"

# Should return:
# {"status":"healthy","service":"gcs-gateway"}
```

**Wait longer**: Large bundles take 60-90 seconds.

**Check logs** (ask operator):
```bash
# Operator runs:
tail -f /tmp/m2-bundler-poll.log
```

### Bundle Download Fails

**Problem**: Bundle URL is wrong or bundle was deleted.

**Solution**:
```bash
# Test URL manually
curl -I BUNDLE_URL

# Should return: HTTP/1.1 200 OK

# If 404, request bundle again
./request-bundle.sh BUNDLE_ID
```

### Bundle Extracted But Clojure Still Downloads

**Problem**: Clojure isn't using the cache.

**Solution**:
```bash
# Verify config
clojure -Spath | grep '\.m2-cache'

# If empty, set CLJ_CONFIG
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'${HOME}'/.m2-cache"}' > $CLJ_CONFIG/deps.edn

# Try again
clojure -Spath | grep '\.m2-cache'
```

### Out of Disk Space

**Problem**: M2 bundles are large (50-500 MB compressed, 2-3 GB extracted).

**Solution**:
```bash
# Check disk space
df -h ~

# Clean old bundles
rm -rf ~/.m2-cache-old/
rm /tmp/m2-*.tar.gz
```

---

## Message Protocol Reference

### Request Format

```clojure
{:schema-version "1.0.0"
 :timestamp "2025-11-15T17:10:00Z"
 :from "claude-code-web-01E7aVp"        ; Your session ID
 :session-id "claude-web-01E7aVp"       ; Same
 :message-id "req-1731700000"           ; Unique request ID
 :type :request
 :payload {:bundle-id "reddit-scraper-server2"  ; Which bundle
           :deps-file nil                       ; Optional custom deps
           :aliases [:dev :test]                ; Optional
           :priority :normal}}                  ; :low, :normal, :high
```

### Response Format

```clojure
{:schema-version "1.0.0"
 :timestamp "2025-11-15T17:12:00Z"
 :from "m2-bundler-service"
 :session-id "claude-web-01E7aVp"
 :message-id "req-1731700000"
 :type :response
 :status :success  ; :success, :error, or :in-progress
 :payload {:bundle-url "https://storage.googleapis.com/..."
           :bundle-size-mb 47
           :artifact-count 81
           :build-time-seconds 12
           :sha256 "abc123..."}}
```

---

## Security & Privacy

### What's Sent to M2 Bundler?

- Session ID (random, doesn't identify you)
- Request ID (random timestamp)
- Bundle ID (which predefined bundle you want)
- Optional custom deps.edn (only if you provide it)

**NOT sent**:
- Your code
- Your project files
- Your identity
- Anything else

### Authentication

- HTTP Basic Auth over HTTPS
- Username: `claude`
- Password: Shared secret (operator provides)
- Credentials never logged or stored server-side

### Bundle Contents

Bundles contain **only**:
- Public Maven JARs (from Maven Central)
- Clojure dependencies
- No proprietary code
- No secrets

**Safe to download!**

---

## FAQ

### Q: How long does a request take?

**A**:
- Small bundles (clojure-minimal, web-stack): ~30-60 seconds
- Large bundles (gcs-client, reddit-scraper-server2): ~60-120 seconds

### Q: Can I request the same bundle multiple times?

**A**: Yes! If the bundle already exists, you'll get the cached version instantly (~5 seconds).

### Q: What if I need a dependency not in any bundle?

**A**: Request a custom bundle with your own deps.edn (see "Custom Bundle Requests" above).

### Q: How often should I request fresh bundles?

**A**: Only when your `deps.edn` changes. Bundles are stable and reusable.

### Q: Can I share bundles with other Claude agents?

**A**: Yes! Bundles are public-read. Just share the bundle URL.

### Q: What if the gateway is down?

**A**: Ask your operator to check Cloud Run status. Gateway has 99.95% uptime SLA.

### Q: How do I know if a bundle is malicious?

**A**: Bundles only contain JARs from Maven Central (public repository). Operator builds bundles using official Clojure tools. No custom code injection.

---

## Complete Example Workflow

```bash
# 1. Setup (one-time)
source .env  # Load credentials

# 2. Request bundle
./request-bundle.sh reddit-scraper-server2
# OUTPUT:
#   ✅ Request submitted: req-1731700500
#   Session: claude-web-1731700456
#   Bundle: reddit-scraper-server2

# 3. Check status (wait ~60s)
./check-status.sh claude-web-1731700456 req-1731700500
# OUTPUT: ⏳ Still processing...

# Wait 30s, try again
sleep 30
./check-status.sh claude-web-1731700456 req-1731700500
# OUTPUT:
#   ✅ Response received!
#   Download with: ./download-bundle.sh https://storage.googleapis.com/.../bundle.tar.gz

# 4. Download bundle
./download-bundle.sh https://storage.googleapis.com/gene-m2-bundler-bundles/bundles/reddit-scraper-server2-1731700567.tar.gz
# OUTPUT:
#   ✅ Bundle extracted to: /Users/claude/.m2-cache

# 5. Configure Clojure
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'${HOME}'/.m2-cache"}' > $CLJ_CONFIG/deps.edn

# 6. Use bundle
cd /path/to/your/project
clojure -M:dev -m server2.core
# No dependency downloads! Uses cached JARs.

# 7. Profit! 🎉
```

---

## Support

**Issues**: Ask your operator or check https://github.com/realgenekim/m2builder/issues

**Operator Contact**: @realgenekim

**Test Gateway**: `curl ${GCS_GATEWAY_URL}/health`

---

**You're ready to request bundles!** Start with `./request-bundle.sh clojure-minimal` to test. 🚀

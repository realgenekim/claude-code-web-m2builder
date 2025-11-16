# Claude Sandboxed Agent - M2 Bundle Download Guide

**For**: Sandboxed Claude Code agents that need Maven/Clojure dependencies

**You have**: Only `curl` and basic shell tools

**You need**: Pre-built Maven dependency bundles

---

## Quick Start (Copy-Paste Ready!)

### Option 1: Direct Download (No Gateway - Simplest!)

Use this if you just need to download the complete reddit-scraper-server2 bundle:

```bash
# 1. Install Clojure CLI (if not already installed)
# See "Installing Clojure" section below if this fails

# 2. Download complete bundle (83 MB, 257 JARs)
mkdir -p ~/.m2-cache
cd ~/.m2-cache
curl -L -o bundle.tar.gz \
  https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz

# 3. Extract bundle
tar -xzf bundle.tar.gz
rm bundle.tar.gz

# 4. Configure Clojure to use the bundle
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'$HOME'/.m2-cache"}' > $CLJ_CONFIG/deps.edn

# 5. Verify it works
clojure -Spath | head -3
# Should show paths from ~/.m2-cache/org/clojure/...

# 6. Done! Use Clojure normally
clojure -M:dev:test:run-tests
```

**Total time**: ~30 seconds (depending on download speed)

---

## Installing Clojure (If Not Already Installed)

Sandboxes often don't have Clojure pre-installed. Here are copy-paste-ready installation commands:

### macOS / Linux (Homebrew)

```bash
# Check if brew is available
which brew

# If brew is installed:
brew install clojure/tools/clojure

# Verify
clojure --version
```

### macOS / Linux (Manual Install - No Homebrew)

```bash
# Download Clojure installer
cd /tmp
curl -L -O https://github.com/clojure/brew-install/releases/latest/download/linux-install.sh
chmod +x linux-install.sh

# Install to user directory (no sudo needed)
./linux-install.sh --prefix ~/.local

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Verify
clojure --version
```

### If Installation Fails

If you can't install Clojure in the sandbox, you have two options:

**Option A**: Ask your operator to pre-install Clojure in the sandbox image

**Option B**: Use the M2 bundle request system (requires gateway setup - see below)

---

## Available Bundles (Direct Download)

All bundles are publicly accessible at:
```
https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/
```

### reddit-scraper-server2 COMPLETE Bundle

**Includes**: ALL dependencies (Maven, local, and transitive) - everything the project needs!

**Download URL**:
```
https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz
```

**Stats**:
- Size: 71 MB compressed, 92 MB uncompressed
- JARs: 252 artifacts
- Includes: All Maven deps + transitive deps from local/git dependencies
- Missing from old bundle: `data.csv`, `reitit-spec`, `google-cloud-bom`, etc.

**Copy-paste download**:
```bash
mkdir -p ~/.m2-cache && cd ~/.m2-cache && \
curl -L -o bundle.tar.gz https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz && \
tar -xzf bundle.tar.gz && rm bundle.tar.gz && \
export CLJ_CONFIG=/tmp/.clj-config && mkdir -p $CLJ_CONFIG && \
echo '{:mvn/local-repo "'$HOME'/.m2-cache"}' > $CLJ_CONFIG/deps.edn && \
echo "✅ Bundle ready! Verify with: clojure -Spath | head -3"
```

### Other Available Bundles

**reddit-scraper-server2 (OLD - Incomplete)**:
- Size: 24 MB
- JARs: 129 (missing many transitive deps)
- **Not recommended** - use COMPLETE version above

**clojure-minimal**:
- Size: 5 MB
- JARs: 3
- Just Clojure core
- URL: `...m2/clojure-minimal-latest.tar.gz` (not yet uploaded)

---

## Using the Bundle

### Method 1: Environment Variable (Recommended)

Set `CLJ_CONFIG` to point to a temporary config:

```bash
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'$HOME'/.m2-cache"}' > $CLJ_CONFIG/deps.edn

# Verify
clojure -Spath | grep '.m2-cache' | head -3
```

**Why this works**: Clojure reads config from `$CLJ_CONFIG/deps.edn` instead of `~/.clojure/deps.edn`

### Method 2: Per-Command (Good for Testing)

```bash
clojure -Sdeps '{:mvn/local-repo "'$HOME'/.m2-cache"}' -M:dev
```

**Why this works**: `-Sdeps` overrides the local repo location just for this command

### Method 3: Global Config (Persists)

```bash
mkdir -p ~/.clojure
echo '{:mvn/local-repo "'$HOME'/.m2-cache"}' > ~/.clojure/deps.edn
```

**Warning**: This affects ALL Clojure projects on your system!

---

## Verifying the Bundle

After download and configuration, verify everything works:

```bash
# Check that Clojure sees the bundle
clojure -Spath | grep '.m2-cache' | head -5

# Should output paths like:
# /Users/claude/.m2-cache/org/clojure/clojure/1.11.3/clojure-1.11.3.jar
# /Users/claude/.m2-cache/http-kit/http-kit/2.8.0/http-kit-2.8.0.jar
# ...

# Check bundle size
du -sh ~/.m2-cache
# Should show: 92M

# Count JARs
find ~/.m2-cache -name "*.jar" | wc -l
# Should show: 252

# Check for previously missing deps
find ~/.m2-cache -name "*data.csv*" -o -name "*reitit-spec*" | head -2
# Should find: data.csv-1.0.0.jar, reitit-spec-0.7.0.jar
```

---

## Troubleshooting

### "clojure: command not found"

**Problem**: Clojure CLI is not installed in sandbox.

**Solution**: See "Installing Clojure" section above. If installation fails, ask operator to pre-install Clojure.

### "Downloading dependencies..." even after bundle extraction

**Problem**: Clojure is not using the bundle cache.

**Solution**:
```bash
# Verify CLJ_CONFIG is set
echo $CLJ_CONFIG
# Should output: /tmp/.clj-config

# Verify config file exists
cat $CLJ_CONFIG/deps.edn
# Should output: {:mvn/local-repo "/Users/claude/.m2-cache"}

# If not set, re-run configuration:
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'$HOME'/.m2-cache"}' > $CLJ_CONFIG/deps.edn
```

### "Could not find artifact org.clojure/data.csv"

**Problem**: Using the OLD incomplete bundle instead of COMPLETE bundle.

**Solution**: Re-download the COMPLETE bundle:
```bash
rm -rf ~/.m2-cache
mkdir -p ~/.m2-cache && cd ~/.m2-cache
curl -L -o bundle.tar.gz \
  https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz
tar -xzf bundle.tar.gz && rm bundle.tar.gz
```

### Bundle download is slow

**Problem**: 71 MB takes time to download.

**Solution**: Be patient! Progress indicator:
```bash
curl -L -o bundle.tar.gz --progress-bar \
  https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz
```

### Out of disk space

**Problem**: Bundle is 92 MB uncompressed.

**Solution**: Check available space:
```bash
df -h ~
# Need at least 100 MB free

# If low, clean up old files
rm -rf /tmp/*.tar.gz
```

---

## Advanced: Request/Response System (NOW LIVE!)

**Gateway URL**: https://m2-gateway-1018897188794.us-central1.run.app

The gateway is deployed! You can now request bundles via HTTP:

### Step 1: Set Credentials

```bash
export GATEWAY_URL="https://m2-gateway-1018897188794.us-central1.run.app"
export GATEWAY_AUTH="claude:f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd"
```

### Step 2: Request Bundle

```bash
curl -s -X POST $GATEWAY_URL/request \
  -u $GATEWAY_AUTH \
  -H "Content-Type: application/json" \
  -d '{"bundle_id": "reddit-scraper-server2"}'

# Response:
# {
#   "request_id": "req-1763260804562",
#   "session_id": "gateway-session-1763260804562",
#   "status": "submitted"
# }
# SAVE the session_id and request_id!
```

### Step 3: Check Status

```bash
# Replace with your session_id and request_id
curl -s $GATEWAY_URL/status/SESSION_ID/REQUEST_ID -u $GATEWAY_AUTH

# Response (when pending):
# {"status": "pending", "message": "Request is still being processed"}

# Response (when completed):
# {"status": "completed", "response_edn": "...bundle URL in here..."}
```

### Step 4: Download Bundle

Once you get the bundle URL from the response, download it:

```bash
curl -L -o ~/.m2-cache/bundle.tar.gz BUNDLE_URL
```

Or use the pre-built COMPLETE bundle directly (recommended):

```bash
curl -L -o ~/.m2-cache/bundle.tar.gz \
  https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz
```

---

## Complete Working Example

Here's a complete copy-paste workflow from scratch:

```bash
# === SETUP ===

# 1. Install Clojure (if needed)
# On macOS with Homebrew:
brew install clojure/tools/clojure

# On Linux without brew:
cd /tmp && \
curl -L -O https://github.com/clojure/brew-install/releases/latest/download/linux-install.sh && \
chmod +x linux-install.sh && \
./linux-install.sh --prefix ~/.local && \
export PATH="$HOME/.local/bin:$PATH"

# === DOWNLOAD BUNDLE ===

# 2. Download and extract COMPLETE bundle
mkdir -p ~/.m2-cache && cd ~/.m2-cache && \
curl -L -o bundle.tar.gz \
  https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz && \
tar -xzf bundle.tar.gz && \
rm bundle.tar.gz && \
echo "✅ Bundle extracted (92 MB, 252 JARs)"

# === CONFIGURE CLOJURE ===

# 3. Configure Clojure to use bundle
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'$HOME'/.m2-cache"}' > $CLJ_CONFIG/deps.edn

# === VERIFY ===

# 4. Verify bundle works
echo "Checking classpath..."
clojure -Spath | grep '.m2-cache' | head -3

echo "Checking missing deps are present..."
find ~/.m2-cache -name "*data.csv*" -o -name "*reitit-spec*" | head -2

echo "Counting JARs..."
find ~/.m2-cache -name "*.jar" | wc -l

# === USE ===

# 5. Use Clojure normally (no Maven downloads!)
cd /path/to/your/project
clojure -M:dev:test:run-tests

# 🎉 Done!
```

---

## What's in the COMPLETE Bundle?

The COMPLETE bundle contains all dependencies needed to run reddit-scraper-server2:

**Direct Maven Dependencies** (from `deps.edn`):
- `org.clojure/clojure`
- `http-kit/http-kit`
- `ring/ring-core`, `ring/ring-defaults`, `ring-basic-authentication`
- `metosin/reitit`, `metosin/reitit-ring`, `metosin/reitit-spec`
- `metosin/muuntaja`
- `hiccup/hiccup`
- `com.stuartsierra/component`
- `com.fulcrologic/guardrails`
- `com.taoensso/timbre`
- And more...

**Transitive Dependencies** (resolved automatically):
- `org.clojure/data.csv` ✅ (was missing in old bundle)
- `com.google.cloud/google-cloud-bom` ✅ (was missing)
- `metosin/reitit-spec` ✅ (was missing)
- All Google Cloud Storage client libs
- All HTTP/web dependencies
- All JSON/data parsing libs
- 200+ more transitive deps

**Total**: 252 JARs, 92 MB uncompressed, 71 MB compressed

---

## Support & Contact

**Issues**: https://github.com/realgenekim/m2builder/issues

**Operator**: @realgenekim

**Test Bundle URL**: 
```bash
curl -I https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz
# Should return: HTTP/1.1 200 OK
```

---

## TL;DR - One-Liner

```bash
mkdir -p ~/.m2-cache && cd ~/.m2-cache && curl -L -o bundle.tar.gz https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz && tar -xzf bundle.tar.gz && rm bundle.tar.gz && export CLJ_CONFIG=/tmp/.clj-config && mkdir -p $CLJ_CONFIG && echo '{:mvn/local-repo "'$HOME'/.m2-cache"}' > $CLJ_CONFIG/deps.edn && clojure -Spath | grep '.m2-cache' | head -3
```

Copy, paste, profit! 🚀

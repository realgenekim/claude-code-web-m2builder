# Test Prompt for Sandboxed Environment

Copy and paste this prompt into your sandboxed Claude Code Web session to test the M2 bundle mailbox system:

---

## Test Prompt

I need to test the M2 bundle mailbox system. Please help me request and use a dependency bundle:

**Step 1: Request a Bundle**

Create a branch to request the `web-stack` bundle (contains Ring, Compojure, Reitit, Cheshire - common web dependencies):

```bash
# Clone the repo if not already in it
git clone https://github.com/realgenekim/claude-code-web-m2builder.git
cd claude-code-web-m2builder

# Create a claude/ branch to trigger the bundle build
TIMESTAMP=$(date +%s)
BRANCH_NAME="claude/bundle-request-web-stack-${TIMESTAMP}"

git checkout -b "${BRANCH_NAME}"

# Add a simple request file (optional, but helps with tracking)
mkdir -p requests
echo "Requesting web-stack bundle from sandboxed environment" > requests/test-request.txt

git add requests/
git commit -m "Request: web-stack bundle"
git push origin HEAD

echo "✅ Request submitted!"
echo "Branch: ${BRANCH_NAME}"
```

**Step 2: Wait for the Build**

The GitHub Action will:
- Detect your claude/ branch
- Build the bundle (takes ~20-30 seconds for web-stack)
- Upload to GitHub Release

You can check the build status:

```bash
gh run list --limit 3
```

**Step 3: Download the Bundle**

After ~30 seconds, download the bundle directly from the Release:

```bash
# Download the web-stack bundle
curl -L -O https://github.com/realgenekim/claude-code-web-m2builder/releases/download/m2-bundles/m2-web-stack.tar.gz

# Check the size
ls -lh m2-web-stack.tar.gz

# Extract it
mkdir -p ~/.m2-cache
tar xzf m2-web-stack.tar.gz -C ~/.m2-cache/

# Verify the contents
find ~/.m2-cache/m2-web-stack -name "*.jar" | wc -l
echo "Expected: ~98 JARs"
```

**Step 4: Use the Bundle**

Create a test Clojure project that uses the bundle:

```bash
# Create test project
mkdir -p /tmp/test-web-app
cd /tmp/test-web-app

# Create deps.edn
cat > deps.edn <<'EOF'
{:deps {ring/ring-core {:mvn/version "1.12.2"}
        ring/ring-jetty-adapter {:mvn/version "1.12.2"}
        compojure/compojure {:mvn/version "1.7.1"}}}
EOF

# Create a simple web app
cat > hello.clj <<'EOF'
(ns hello
  (:require [ring.adapter.jetty :as jetty]
            [compojure.core :refer [defroutes GET]]
            [compojure.route :as route]))

(defroutes app
  (GET "/" [] "Hello from sandboxed M2 cache!")
  (route/not-found "Not Found"))

(defn -main []
  (println "Starting server on port 3000...")
  (jetty/run-jetty app {:port 3000 :join? false}))
EOF

# Run using the cached dependencies (no Maven Central access needed!)
clojure -Sdeps '{:mvn/local-repo "'$HOME'/.m2-cache/m2-web-stack"}' \
        -M -m hello

# You should see: "Starting server on port 3000..."
# This proves the dependencies work without internet access to Maven Central!
```

**Step 5: Verify Success**

Check that everything worked:

```bash
echo "✅ Test Results:"
echo ""
echo "1. Bundle downloaded: $(ls -lh ~/.m2-cache/m2-web-stack.tar.gz 2>/dev/null && echo 'YES' || echo 'NO')"
echo "2. Bundle extracted: $([ -d ~/.m2-cache/m2-web-stack ] && echo 'YES' || echo 'NO')"
echo "3. JARs present: $(find ~/.m2-cache/m2-web-stack -name '*.jar' 2>/dev/null | wc -l) (expected: ~98)"
echo "4. Clojure can use it: Try running the hello.clj app above"
```

---

## Available Bundles

You can request any of these bundles by changing the branch name:

| Bundle ID | Description | Size | JARs |
|-----------|-------------|------|------|
| `clojure-minimal` | Pure Clojure stdlib only | 5 MB | 3 |
| `web-stack` | Ring + Compojure + Reitit + Cheshire | 17 MB | 98 |
| `gcs-client` | Google Cloud Storage client | 47 MB | 81 |
| `reddit-scraper-server2` | Reddit scraper dependencies | 24 MB | 129 |

**To request a different bundle**, just change the branch name:
```bash
git checkout -b claude/bundle-request-gcs-client-$(date +%s)
```

---

## Troubleshooting

**If the bundle isn't available after 60 seconds:**

Check the GitHub Actions run:
```bash
gh run list --limit 1
gh run view $(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
```

**If you get "Resource not accessible":**

The bundles are public! You can always download directly:
```bash
curl -L -O https://github.com/realgenekim/claude-code-web-m2builder/releases/download/m2-bundles/m2-BUNDLE-NAME.tar.gz
```

Replace `BUNDLE-NAME` with: `web-stack`, `gcs-client`, `clojure-minimal`, or `reddit-scraper-server2`

---

## What This Proves

This test demonstrates:

1. ✅ **Sandboxed environments** can request dependencies without Maven Central access
2. ✅ **GitHub Actions** builds bundles automatically from branch requests
3. ✅ **GitHub Releases** serves bundles via public HTTPS (no auth needed)
4. ✅ **Clojure projects** can use the cached dependencies completely offline
5. ✅ **The entire workflow** works end-to-end (request → build → download → use)

**This is the "mailbox" pattern in action!** 📬

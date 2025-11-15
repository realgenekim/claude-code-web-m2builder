# Sandboxed Agent Interaction Example

## Scenario: Claude Code Web Needs Dependencies

This document shows a concrete, step-by-step example of how a sandboxed coding agent (Claude Code Web) requests Maven dependencies it can't access and receives a prewarmed .m2 bundle via the GitHub-based mailbox system.

---

## Cast of Characters

- **Claude Code Web** (sandboxed agent): Running in browser, no direct Maven access
- **Local Wrapper** (`m2-helper.sh`): Script on your laptop that monitors Claude's output
- **GitHub Repository** (`realgenekim/m2builder`): Message bus
- **GitHub Actions**: Networked build agent
- **You**: The human operator

---

## Timeline: Complete Interaction

### T+0:00 - User Asks Claude to Build Something

**User** (in browser):
```
Hey Claude, can you help me build a simple web server using Ring and Compojure?
```

**Claude Code Web** (thinks):
```
I need to compile Clojure code with Ring and Compojure dependencies.
Let me try to resolve deps.edn...

Checking local .m2 cache... not found.
I'm in a sandbox, can't access Maven Central directly.
I'll signal that I need help.
```

### T+0:01 - Claude Signals Need for Dependencies

**Claude Code Web** (writes to shared volume `/workspace/m2-requests/`):

```bash
# File: /workspace/m2-requests/request-1731682801.edn
{:job-id "request-1731682801"
 :requested-by "claude-code-web"
 :timestamp "2025-11-15T10:00:01Z"
 :description "Need Ring + Compojure for web server"
 :deps
 {ring/ring-core {:mvn/version "1.12.2"}
  ring/ring-jetty-adapter {:mvn/version "1.12.2"}
  compojure/compojure {:mvn/version "1.7.1"}
  cheshire/cheshire {:mvn/version "5.12.0"}}}
```

**Claude Code Web** (prints to stdout):
```
⏳ Waiting for dependencies: request-1731682801
   I've requested Ring + Compojure. Checking mailbox for response...
```

---

### T+0:02 - Local Wrapper Detects Request

**Local Wrapper** (`m2-helper.sh` running on your laptop, monitoring `/workspace/m2-requests/`):

```bash
#!/usr/bin/env bash
# m2-helper.sh (runs in background)

while true; do
  # Check for new requests
  for REQUEST_FILE in /workspace/m2-requests/*.edn; do
    [ -e "$REQUEST_FILE" ] || continue

    JOB_ID=$(basename "$REQUEST_FILE" .edn)

    echo "📬 New request detected: $JOB_ID"
    echo "   File: $REQUEST_FILE"

    # Copy to GitHub repo
    cp "$REQUEST_FILE" ~/src.local/m2builder/deps-requests/

    cd ~/src.local/m2builder

    # Commit and push
    git add deps-requests/$JOB_ID.edn
    git commit -m "Request: $JOB_ID from Claude Code Web"
    git push origin main

    echo "✅ Request sent to GitHub"
    echo "   Workflow: https://github.com/realgenekim/m2builder/actions"

    # Mark as sent
    mv "$REQUEST_FILE" "/workspace/m2-requests/.sent/$JOB_ID.edn"
  done

  sleep 5
done
```

**Terminal output**:
```
📬 New request detected: request-1731682801
   File: /workspace/m2-requests/request-1731682801.edn
✅ Request sent to GitHub
   Workflow: https://github.com/realgenekim/m2builder/actions
```

---

### T+0:03 - GitHub Receives Request (Push Event)

**Git log**:
```
commit a1b2c3d4
Author: m2-helper <helper@local>
Date:   Fri Nov 15 10:00:03 2025 -0800

    Request: request-1731682801 from Claude Code Web

    Files changed:
     deps-requests/request-1731682801.edn | 8 ++++++++
```

**GitHub** (detects push):
```
🔔 Push event on main branch
   Files changed: deps-requests/request-1731682801.edn
   Matching workflow: .github/workflows/build-bundle.yml
   Trigger: paths: ['deps-requests/*.edn']

▶️  Starting workflow run #42...
```

---

### T+0:04 - GitHub Actions Starts Building

**Workflow run** (`https://github.com/realgenekim/m2builder/actions/runs/42`):

```yaml
# Job: build-request
# Run: #42
# Status: In progress

Run: Detect changed requests
  Changed files:
    deps-requests/request-1731682801.edn
  ✅ 1 new request detected

Run: Extract job metadata
  JOB_ID: request-1731682801
  DESCRIPTION: Need Ring + Compojure for web server
  ✅ Metadata extracted

Run: Setup Clojure
  Installing Clojure CLI 1.11.3.1463...
  ✅ Clojure installed

Run: Parse deps manifest
  Reading deps-requests/request-1731682801.edn...
  Creating temporary deps.edn...

  {
    :deps {
      ring/ring-core {:mvn/version "1.12.2"}
      ring/ring-jetty-adapter {:mvn/version "1.12.2"}
      compojure/compojure {:mvn/version "1.7.1"}
      cheshire/cheshire {:mvn/version "5.12.0"}
    }
  }

  ✅ deps.edn created

Run: Warm M2 cache
  $ clojure -Srepro -Sforce \
      -Sdeps '{:mvn/local-repo "/tmp/m2-request-1731682801"}' \
      -P

  Downloading: ring/ring-core 1.12.2
    https://repo1.maven.org/maven2/ring/ring-core/1.12.2/ring-core-1.12.2.pom
    https://repo1.maven.org/maven2/ring/ring-core/1.12.2/ring-core-1.12.2.jar
  Downloading: ring/ring-jetty-adapter 1.12.2
  Downloading: compojure/compojure 1.7.1
  Downloading: cheshire/cheshire 5.12.0
  [... many transitive deps ...]

  Downloaded 47 artifacts (42.3 MB)
  ✅ M2 cache warmed

Run: Create tarball
  $ tar czf m2-request-1731682801.tar.gz \
      -C /tmp m2-request-1731682801

  Created: m2-request-1731682801.tar.gz (38.2 MB)
  ✅ Tarball created

Run: Upload to GitHub Release
  $ gh release upload m2-bundles \
      m2-request-1731682801.tar.gz --clobber

  ✅ Uploaded to release 'm2-bundles'

  Public URL:
  https://github.com/realgenekim/m2builder/releases/download/m2-bundles/m2-request-1731682801.tar.gz

Run: Write response
  Creating deps-responses/request-1731682801.edn...

  {
    :job-id "request-1731682801"
    :status :ok
    :bundle-url "https://github.com/realgenekim/m2builder/releases/download/m2-bundles/m2-request-1731682801.tar.gz"
    :bundle-size-mb 38
    :created-at "2025-11-15T18:00:27Z"
    :workflow-run "https://github.com/realgenekim/m2builder/actions/runs/42"
  }

  ✅ Response written

Run: Commit response
  $ git config user.name "github-actions[bot]"
  $ git config user.email "github-actions[bot]@users.noreply.github.com"
  $ git add deps-responses/request-1731682801.edn
  $ git commit -m "Response for request-1731682801"
  $ git push

  [main b2c3d4e] Response for request-1731682801
   1 file changed, 7 insertions(+)
   create mode 100644 deps-responses/request-1731682801.edn

  ✅ Response committed and pushed

✅ Workflow completed successfully (duration: 2m 34s)
```

---

### T+2:38 - Local Wrapper Detects Response

**Local Wrapper** (polling for responses):

```bash
# m2-helper.sh (separate polling loop)

while true; do
  cd ~/src.local/m2builder

  # Pull latest
  git pull -q origin main

  # Check for new responses
  for RESPONSE_FILE in deps-responses/*.edn; do
    [ -e "$RESPONSE_FILE" ] || continue

    JOB_ID=$(basename "$RESPONSE_FILE" .edn)

    # Check if we've already processed this
    [ -f "/workspace/m2-responses/$JOB_ID.edn" ] && continue

    echo "📨 Response received: $JOB_ID"

    # Parse response (simplified - use proper EDN parser)
    BUNDLE_URL=$(grep ':bundle-url' "$RESPONSE_FILE" | cut -d'"' -f2)
    BUNDLE_SIZE=$(grep ':bundle-size-mb' "$RESPONSE_FILE" | cut -d' ' -f2)

    echo "   URL: $BUNDLE_URL"
    echo "   Size: ${BUNDLE_SIZE} MB"
    echo ""
    echo "📥 Downloading bundle..."

    # Download
    curl -L -o "/tmp/$JOB_ID.tar.gz" "$BUNDLE_URL"

    echo "📦 Extracting to /workspace/.m2-cache/$JOB_ID..."
    mkdir -p "/workspace/.m2-cache/$JOB_ID"
    tar xzf "/tmp/$JOB_ID.tar.gz" \
        -C "/workspace/.m2-cache/" \
        --strip-components=1

    # Notify Claude
    cp "$RESPONSE_FILE" "/workspace/m2-responses/"

    echo "✅ Bundle ready!"
    echo "   Location: /workspace/.m2-cache/m2-request-1731682801"

    # Cleanup
    rm "/tmp/$JOB_ID.tar.gz"
  done

  sleep 10
done
```

**Terminal output**:
```
📨 Response received: request-1731682801
   URL: https://github.com/realgenekim/m2builder/releases/download/m2-bundles/m2-request-1731682801.tar.gz
   Size: 38 MB

📥 Downloading bundle...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 38.2M  100 38.2M    0     0  45.2M      0 --:--:-- --:--:-- --:--:-- 45.1M

📦 Extracting to /workspace/.m2-cache/request-1731682801...

✅ Bundle ready!
   Location: /workspace/.m2-cache/m2-request-1731682801
```

---

### T+2:45 - Claude Code Web Gets Notified

**Claude Code Web** (polling `/workspace/m2-responses/`):

```
Checking mailbox... [retry 27]

✅ Response found: request-1731682801.edn

Reading response:
  Status: :ok
  Bundle location: /workspace/.m2-cache/m2-request-1731682801
  Size: 38 MB

Configuring Clojure to use bundle...
  $ export CLJ_CONFIG=/workspace/.clj-config
  $ mkdir -p $CLJ_CONFIG
  $ echo '{:mvn/local-repo "/workspace/.m2-cache/m2-request-1731682801"}' \
      > $CLJ_CONFIG/deps.edn

✅ Dependencies ready! I can now compile your project.

Let me create a simple Ring + Compojure web server...
```

**Claude Code Web** (now has deps, continues with original task):

```clojure
;; File: src/my_server/core.clj

(ns my-server.core
  (:require [ring.adapter.jetty :refer [run-jetty]]
            [compojure.core :refer [defroutes GET]]
            [compojure.route :as route]
            [ring.middleware.json :refer [wrap-json-response]]
            [cheshire.core :as json]))

(defroutes app-routes
  (GET "/" [] {:status 200
               :headers {"Content-Type" "application/json"}
               :body (json/generate-string {:message "Hello from Ring!"})})
  (route/not-found "Not Found"))

(def app
  (-> app-routes
      wrap-json-response))

(defn -main [& args]
  (run-jetty app {:port 3000 :join? false})
  (println "Server running on http://localhost:3000"))
```

**Claude Code Web** (compiles and tests):

```bash
$ clojure -M -m my-server.core

Compiling my-server.core...
  [using .m2 cache from /workspace/.m2-cache/m2-request-1731682801]
  ✅ No errors!

Server running on http://localhost:3000

✅ Your web server is ready!
   Try: curl http://localhost:3000
   Output: {"message":"Hello from Ring!"}
```

---

### T+3:00 - User Sees Result

**User** (in browser):
```
Wow, that worked! Thanks Claude!
```

**Claude Code Web**:
```
You're welcome! The dependency bundle system worked perfectly:

  1. I detected I couldn't access Maven Central
  2. I created a request for Ring + Compojure
  3. GitHub Actions built the bundle in ~2.5 minutes
  4. I downloaded and used the prewarmed .m2 cache
  5. Your server compiled and runs!

Total time: ~3 minutes (most of it was GitHub Actions building)
Next time, if you need the same deps, I can reuse the cached bundle instantly.
```

---

## File System State at Each Stage

### T+0:01 (Claude creates request)

```
/workspace/
├── m2-requests/
│   └── request-1731682801.edn        ← New request
├── m2-responses/
│   └── (empty)
└── .m2-cache/
    └── (empty)

~/src.local/m2builder/
├── deps-requests/
│   └── (empty)
└── deps-responses/
    └── (empty)
```

---

### T+0:03 (After wrapper pushes to GitHub)

```
/workspace/
├── m2-requests/
│   └── .sent/
│       └── request-1731682801.edn    ← Moved to .sent
├── m2-responses/
│   └── (empty)
└── .m2-cache/
    └── (empty)

~/src.local/m2builder/ (Git repo)
├── deps-requests/
│   └── request-1731682801.edn        ← Committed & pushed
└── deps-responses/
    └── (empty)

GitHub (remote)
├── deps-requests/
│   └── request-1731682801.edn        ← Visible on GitHub
└── deps-responses/
    └── (empty)
```

---

### T+2:38 (After GitHub Actions completes)

```
/workspace/
├── m2-requests/
│   └── .sent/
│       └── request-1731682801.edn
├── m2-responses/
│   └── (empty - wrapper hasn't synced yet)
└── .m2-cache/
    └── (empty)

~/src.local/m2builder/ (Git repo - not yet pulled)
├── deps-requests/
│   └── request-1731682801.edn
└── deps-responses/
    └── (empty)

GitHub (remote)
├── deps-requests/
│   └── request-1731682801.edn
├── deps-responses/
│   └── request-1731682801.edn        ← Response committed
└── Releases/
    └── m2-bundles/
        └── m2-request-1731682801.tar.gz  ← Tarball uploaded
```

---

### T+2:45 (After wrapper downloads and extracts)

```
/workspace/
├── m2-requests/
│   └── .sent/
│       └── request-1731682801.edn
├── m2-responses/
│   └── request-1731682801.edn        ← Response copied from repo
├── .m2-cache/
│   └── m2-request-1731682801/        ← Extracted tarball
│       └── repository/
│           ├── ring/
│           ├── compojure/
│           ├── cheshire/
│           └── [... many more deps ...]
└── .clj-config/
    └── deps.edn                       ← Points to .m2-cache

~/src.local/m2builder/ (Git repo - pulled)
├── deps-requests/
│   └── request-1731682801.edn
└── deps-responses/
│   └── request-1731682801.edn        ← Pulled from GitHub

GitHub (remote)
├── deps-requests/
│   └── request-1731682801.edn
├── deps-responses/
│   └── request-1731682801.edn
└── Releases/
    └── m2-bundles/
        └── m2-request-1731682801.tar.gz
```

---

## Sequence Diagram

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Claude Code  │    │ Local        │    │ GitHub       │    │ GitHub       │
│ Web (sandbox)│    │ Wrapper      │    │ Repo         │    │ Actions      │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │                   │
  [User asks to build web server]              │                   │
       │                   │                   │                   │
       │ Need deps!        │                   │                   │
       │ Write request.edn │                   │                   │
       │────────────────────>                  │                   │
       │                   │                   │                   │
       │ ⏳ Waiting...     │                   │                   │
       │                   │                   │                   │
       │                   │ Monitor folder    │                   │
       │                   │ Found new request!│                   │
       │                   │───────┐           │                   │
       │                   │       │           │                   │
       │                   │<──────┘           │                   │
       │                   │                   │                   │
       │                   │ git add/commit/push                   │
       │                   │──────────────────>│                   │
       │                   │                   │                   │
       │                   │                   │ Push event!       │
       │                   │                   │ Trigger workflow  │
       │                   │                   │──────────────────>│
       │                   │                   │                   │
       │                   │                   │                   │ Setup Clojure
       │                   │                   │                   │ Parse deps
       │                   │                   │                   │ Warm M2
       │                   │                   │                   │ Create tarball
       │                   │                   │                   │───────┐
       │                   │                   │                   │       │ [2m 34s]
       │                   │                   │                   │<──────┘
       │                   │                   │                   │
       │                   │                   │ Upload to Release │
       │                   │                   │<──────────────────│
       │                   │                   │                   │
       │                   │                   │ Commit response   │
       │                   │                   │<──────────────────│
       │                   │                   │                   │
       │                   │ git pull          │                   │
       │                   │<──────────────────│                   │
       │                   │                   │                   │
       │                   │ Found response!   │                   │
       │                   │ Download tarball  │                   │
       │                   │ (from Release)    │                   │
       │                   │───────────────────────────────┐       │
       │                   │                   │           │       │
       │                   │<──────────────────────────────┘       │
       │                   │                   │                   │
       │                   │ Extract to .m2-cache                  │
       │                   │───────┐           │                   │
       │                   │       │           │                   │
       │                   │<──────┘           │                   │
       │                   │                   │                   │
       │ Bundle ready!     │                   │                   │
       │<──────────────────│                   │                   │
       │                   │                   │                   │
       │ ✅ Compile code   │                   │                   │
       │ ✅ Run server     │                   │                   │
       │                   │                   │                   │
  [User sees working server]                   │                   │
       │                   │                   │                   │
```

---

## Messages Logged (Chronological)

### T+0:01 - Claude's Console
```
⏳ Waiting for dependencies: request-1731682801
   I've requested Ring + Compojure. Checking mailbox for response...
   [Will retry every 10 seconds, timeout in 5 minutes]
```

### T+0:02 - Wrapper's Terminal
```
📬 New request detected: request-1731682801
   File: /workspace/m2-requests/request-1731682801.edn
✅ Request sent to GitHub
   Workflow: https://github.com/realgenekim/m2builder/actions
```

### T+0:04 - GitHub Actions Log
```
Run #42 started
  Job: build-request
  Triggered by: push to main (deps-requests/request-1731682801.edn)

[00:00:03] Setup Clojure ✅
[00:00:15] Parse deps manifest ✅
[00:02:18] Warm M2 cache ✅ (47 artifacts, 42.3 MB)
[00:02:24] Create tarball ✅ (38.2 MB)
[00:02:27] Upload to Release ✅
[00:02:32] Write response ✅
[00:02:34] Commit response ✅

✅ Workflow completed (2m 34s)
```

### T+2:38 - Wrapper's Terminal
```
📨 Response received: request-1731682801
   URL: https://github.com/realgenekim/m2builder/releases/download/m2-bundles/m2-request-1731682801.tar.gz
   Size: 38 MB

📥 Downloading bundle... done (0m 51s)
📦 Extracting... done
✅ Bundle ready at /workspace/.m2-cache/m2-request-1731682801
```

### T+2:45 - Claude's Console
```
✅ Response found: request-1731682801.edn
✅ Dependencies ready! Configuring Clojure...
✅ Compiling my-server.core... success!
✅ Server running on http://localhost:3000
```

---

## What Just Happened? (Summary)

1. **Sandboxed agent** detected it needed Maven deps it couldn't access
2. **Agent wrote** an EDN request file to a shared folder
3. **Local wrapper** noticed the request, committed to Git, pushed to GitHub
4. **GitHub detected** the push, triggered Actions workflow
5. **GitHub Actions** built the .m2 cache (2.5 minutes)
6. **Actions uploaded** tarball to Release, committed response to repo
7. **Local wrapper** pulled the response, downloaded tarball, extracted it
8. **Agent got notified**, configured Clojure to use the cache, **compiled successfully**

**Total time**: ~3 minutes (mostly GitHub Actions build time)

**Cost**: $0 (public repo)

**Human intervention**: None (fully automated after initial setup)

**Next time**: If Claude needs the same deps, instant reuse of cached bundle!

---

## Alternative: Using Prebuilt Community Bundle

If someone had already defined a `web-stack` bundle, the flow is even simpler:

### T+0:01 - Claude Requests Prebuilt Bundle

**Claude Code Web** (smarter now):
```
I need Ring + Compojure. Let me check if there's a prebuilt bundle...

Checking bundles registry:
  ✅ Found: web-stack (Ring + HTTP-Kit + Cheshire + Compojure)

Writing request for prebuilt bundle:
  {:bundle-id "web-stack"}

⏳ Waiting for bundle...
```

**Request file** (`m2-requests/request-1731682802.edn`):
```clojure
{:job-id "request-1731682802"
 :bundle-id "web-stack"  ; Reference to prebuilt bundle
 :requested-by "claude-code-web"}
```

### T+0:02 - Wrapper Detects Request

**Wrapper**:
```bash
📬 New request: request-1731682802
   Bundle ID: web-stack

Checking if bundle already exists:
  Release URL: https://github.com/realgenekim/m2builder/releases/download/m2-bundles/m2-web-stack.tar.gz

✅ Bundle exists! Skipping GitHub Actions build.

📥 Downloading prebuilt bundle...
```

### T+0:30 - Bundle Downloaded

**Wrapper**:
```
✅ Downloaded m2-web-stack.tar.gz (45 MB)
📦 Extracted to /workspace/.m2-cache/m2-web-stack
📨 Notifying Claude...
```

**Total time**: 30 seconds (no build needed!)

---

This is the power of the community bundle model:
- First request: ~3 minutes (build from scratch)
- Subsequent requests: ~30 seconds (download prebuilt)
- If 10 people use `web-stack`: 1 build, 10 instant downloads

# Claude Instructions for M2 Bundler

## Project Overview

M2 Bundler builds and distributes Maven dependency bundles for sandboxed Clojure environments.

**Purpose**: Allow Claude Code agents in restricted environments to download pre-built M2 caches instead of accessing Maven Central directly.

---

## Development Environment

### REPL-Driven Development

**Start REPL with MCP**:
```bash
make nrepl        # Terminal 1: Start nREPL server
make mcp-run      # Terminal 2: Start MCP server (connects to nREPL)
```

**Then use Clojure MCP tools** in Claude Code to evaluate code interactively.

### Key Namespaces

```clojure
(require '[m2builder.bundle :as bundle])
(require '[m2builder.core :as core])

;; List available bundles
(bundle/list-bundles)

;; Build a bundle (test with clojure-minimal first - it's fast!)
(bundle/build-bundle {:bundle-id "clojure-minimal"
                      :upload? false
                      :cleanup? false})

;; Build and upload to GCS
(bundle/build-bundle {:bundle-id "reddit-scraper-server2"})
```

---

## Issue Tracking with Beads

**Beads is initialized** in `.beads/m2builder.db`

### Common Commands

```bash
# Create issues
bd create "Add mailbox polling functionality"
bd create "Write tests for bundle building" -p 1 -t test

# List issues
bd list
bd list --status open

# Show ready work (no blocking dependencies)
bd ready

# Update issues
bd update m2builder-1 --status in_progress
bd close m2builder-2 --reason "Completed and tested"

# Add dependencies (task B blocks task A)
bd dep add m2builder-1 m2builder-2  # m2builder-2 must complete first
```

### Integration with Claude

When working on tasks:
1. **Check `bd ready`** for unblocked work
2. **Update status** when starting: `bd update ISSUE --status in_progress`
3. **Create new issues** when discovering related work
4. **Close when done**: `bd close ISSUE --reason "description"`

---

## GCS Bucket Structure

**Bucket**: `gs://gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/`

```
gs://gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/
├── m2/                           # Maven bundles (public-read)
│   ├── reddit-scraper-server2-COMPLETE-latest.tar.gz       # ✅ RECOMMENDED (252 JARs, 71 MB)
│   ├── reddit-scraper-server2-COMPLETE-{timestamp}.tar.gz
│   ├── reddit-scraper-server2-latest.tar.gz                # OLD (129 JARs, 24 MB) - missing deps!
│   ├── reddit-scraper-server2-{timestamp}.tar.gz
│   └── metadata/
│       ├── reddit-scraper-server2-COMPLETE-{timestamp}.json
│       ├── reddit-scraper-server2-{timestamp}.json
│       └── ...
│
└── mailbox/                      # Request/response (to be implemented)
    ├── requests/
    │   └── {session-id}/{request-id}.edn
    ├── responses/
    │   └── {session-id}/{request-id}.edn
    └── processed/
        └── {session-id}/{request-id}.edn
```

**Important**: The COMPLETE bundles contain ALL dependencies (including transitive deps from local/git dependencies). Always use COMPLETE bundles for production.

---

## Building Bundles

### Quick Test (Fast)

```clojure
;; In REPL (clojure-minimal is ~5 seconds)
(bundle/build-bundle {:bundle-id "clojure-minimal"
                      :upload? false
                      :cleanup? false})
```

### Production Build

```clojure
;; In REPL (reddit-scraper-server2 is ~30 seconds)
(bundle/build-bundle {:bundle-id "reddit-scraper-server2"})
```

**Result**:
- Downloads 129 JARs (~30 MB uncompressed)
- Creates tarball (24.4 MB compressed)
- Uploads to GCS
- Public URL: https://storage.googleapis.com/.../m2/reddit-scraper-server2-latest.tar.gz

---

## Testing Bundles

### Download and Verify

```bash
# Download COMPLETE bundle (recommended)
mkdir -p ~/.m2-cache-test
cd ~/.m2-cache-test
curl -L -O https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-COMPLETE-latest.tar.gz

# Extract
tar -xzf reddit-scraper-server2-COMPLETE-latest.tar.gz

# Verify
find . -name "*.jar" | wc -l  # Should show 252
du -sh .                       # Should show ~92M
```

### Use with Clojure

```bash
# Configure Clojure to use bundle
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "'$HOME'/.m2-cache-test"}' > $CLJ_CONFIG/deps.edn

# Test
cd ../reddit-scraper-fulcro/server2
clojure -Spath | grep '.m2-cache-test'  # Should show JARs from bundle
```

---

## Running Tests

```bash
# Watch mode (auto-runs on file changes)
make runtests

# One-time run (fail-fast)
make runtests-once
```

**Note**: Currently no tests implemented - compilation check only.

---

## Documentation

- **[Agent Collaboration Plan](docs/agent-collaboration-plan.md)** - Overall architecture
- **[M2 Bundler Operations](docs/m2-bundler-operations.md)** - Service operator guide
- **[Bundle Creation Process](docs/bundle-creation-process.md)** - Step-by-step tarball creation
- **[Sandboxed Agent Guide](claude-sandboxed/README.md)** - Copy-paste instructions for Claude Code agents in sandboxes

---

## Next Steps (Check Beads Issues)

```bash
bd ready  # Show issues ready to work on
```

### High Priority

1. **Mailbox functionality** - Request/response message handling
2. **Polling script** - Monitor mailbox for incoming requests
3. **Python Flask gateway** - HTTP gateway for sandboxed agents
4. **End-to-end testing** - Test complete workflow

---

## Common Tasks

### Create a New Bundle Definition

```clojure
;; 1. Create bundles/my-bundle.edn
{:schema-version "1.0.0"
 :bundle-id "my-bundle"
 :version "1.0.0"
 :description "My custom bundle"
 :deps {org.clojure/clojure {:mvn/version "1.11.3"}
        my/library {:mvn/version "1.0.0"}}}

;; 2. Test build
(bundle/build-bundle {:bundle-id "my-bundle" :upload? false})

;; 3. If good, upload
(bundle/build-bundle {:bundle-id "my-bundle"})
```

### Update Existing Bundle

```bash
# Edit bundles/reddit-scraper-server2.edn
vim bundles/reddit-scraper-server2.edn

# Rebuild and upload
```

```clojure
(bundle/build-bundle {:bundle-id "reddit-scraper-server2"})
```

---

## Troubleshooting

### "Downloaded 0 JARs"

The bundle builder needs to write a `deps.edn` file to a temp directory. Fixed in current version.

### "MCP not working"

```bash
# Check .nrepl-port exists
ls .nrepl-port

# Restart nREPL
make nrepl

# In another terminal
make mcp-run
```

### "Bundle missing dependencies"

Check the bundle definition includes all required deps. Clojure automatically resolves transitives, so you only need to specify direct dependencies.

---

## Style Guide

- Use `mcp__clojure-mcp__clojure_eval` for REPL evaluation
- Use `mcp__clojure-mcp__clojure_edit` for code editing (preserves structure)
- Always test builds with `clojure-minimal` first (fast iteration)
- Update Beads issues as you work
- Document significant decisions in docs/

---

**Happy Building!** 🚀

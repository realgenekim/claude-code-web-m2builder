# Agent Communication Patterns for Sandboxed Environments

## Problem Statement

Sandboxed coding agents (Codex CLI, Claude Code, etc.) operate in restricted container environments with limited network access. They cannot directly access external resources like Maven Central or Google Cloud Storage. This creates a challenge when agents need to share resources, particularly Maven/Clojure dependency caches (.m2 directories).

## The Core Challenge

**Two environments need to communicate:**
- **Agent A (Sandboxed)**: Limited network, can't access Maven Central or GCS, may not have `gcloud` CLI
- **Agent B (Networked)**: Full internet access, can fetch from Maven Central, can write to cloud storage

**Communication needs:**
1. Agent A says "I need these dependencies"
2. Agent B fetches them, warms an .m2 cache, packages it
3. Agent A retrieves and uses the .m2 bundle
4. All without direct peer-to-peer networking

## 10 Communication Patterns

### Pattern 1: Local Folder as Mailbox
**Concept**: Use shared host-mounted directory for request/response files.

**How it works**:
- Agent A writes `requests/job-123.edn` (deps manifest)
- Host script notices new file
- Host script runs networked helper container to warm .m2
- Helper uploads tarball to GCS
- Host writes `responses/job-123.edn` with GCS URL
- Agent A polls responses folder

**Pros**:
- Stupid simple, just files
- No network needed in sandbox
- Great for Codex CLI wrapped by shell script

**Cons**:
- Requires shared filesystem
- Manual polling

**Best for**: Local development, single-machine setups

---

### Pattern 2: Git Repo as Message Bus
**Concept**: Use dedicated Git repo where files = messages.

**How it works**:
- Agent A writes `deps-requests/job-123.edn` and commits/pushes
- CI job or cron watches for new files
- CI performs m2-warming and GCS upload
- CI writes `deps-responses/job-123.edn` and commits
- Agent A does `git pull` and checks responses

**Pros**:
- Built-in history and audit trail
- Diffable, debuggable
- Works across machines
- Fits existing Git workflows

**Cons**:
- Git overhead for every message
- Latency from CI polling

**Best for**: Multi-machine environments, teams wanting audit trails

---

### Pattern 3: GCS Bucket Inbox/Outbox
**Concept**: Use GCS objects as messages.

**How it works**:
- Agent A writes `gs://bucket/deps-requests/job-123.json`
- Cloud Function triggers on new objects in `deps-requests/`
- Function warms .m2, uploads tarball, writes `deps-responses/job-123.json`
- Agent A polls GCS for response

**Pros**:
- Cloud-native, scales infinitely
- Works from anywhere
- Event-driven via Cloud Functions

**Cons**:
- Public bucket = cost risk (see security section)
- Requires GCS access or signed URLs
- Not free for private buckets

**Best for**: Cloud-first architectures, multi-region teams

---

### Pattern 4: Simple REST API on Cloud Run
**Concept**: Tiny HTTP service for request/response.

**How it works**:
- Deploy minimal service to Cloud Run
- `POST /requests` with deps manifest
- `GET /responses/{job-id}` to check status
- Background worker processes jobs

**Pros**:
- Clean API
- Language-agnostic
- Standard HTTP

**Cons**:
- More infrastructure
- Auth complexity
- Cost for always-on service

**Best for**: Teams with existing Cloud Run infrastructure

---

### Pattern 5: Log-Based Protocol (stdout/stdin)
**Concept**: Use structured log lines as protocol.

**How it works**:
- Agent emits: `NEED_M2_JOB {"job-id":"123","deps":{...}}`
- Wrapper script parses stdout
- Wrapper triggers m2-build/upload
- Wrapper prints: `M2_READY {"job-id":"123","m2-url":"gs://..."}`
- Agent reads from stdin or environment

**Pros**:
- Zero network changes
- Leverages existing I/O stream
- Very simple

**Cons**:
- Fragile to log format changes
- Requires careful wrapper implementation

**Best for**: Terminal-based agents, tightly controlled environments

---

### Pattern 6: Makefile Orchestration
**Concept**: Make targets coordinate multi-step workflow.

**How it works**:
```makefile
make request-m2 JOB=123  # Agent emits request file
make build-m2 JOB=123    # Networked env builds .m2
make use-m2 JOB=123      # Agent consumes bundle
```

**Pros**:
- Explicit, debuggable
- Easy to reason about
- Manual or automated

**Cons**:
- Sequential, not asynchronous
- Requires Make knowledge

**Best for**: Local development, explicit step-by-step workflows

---

### Pattern 7: Google Sheets as Job Queue
**Concept**: Spreadsheet as control plane.

**How it works**:
- Sheet has columns: `job_id`, `deps_edn`, `status`, `m2_url`, `logs`
- Agent appends row with `status=pending`
- Apps Script or Cloud Function polls for pending jobs
- Processor updates row with `status=complete` and URL

**Pros**:
- Debuggable with eyeballs
- Easy to edit/fix manually
- Familiar interface

**Cons**:
- Weird abuse of Sheets
- Latency from polling
- Scale limits

**Best for**: Small teams, visual debugging, prototypes

---

### Pattern 8: Email + Cloud Function
**Concept**: Email as transport layer.

**How it works**:
- Agent emails `deps-requests@domain` with manifest in body
- Cloud Function parses incoming mail
- Function builds .m2, uploads, replies with URL
- Agent checks mailbox (IMAP/POP)

**Pros**:
- Works in ultra-locked-down environments
- Email is ubiquitous

**Cons**:
- Bizarre overhead
- Latency
- Email parsing complexity

**Best for**: Environments where only SMTP is allowed

---

### Pattern 9: SSH "Dropbox" on VM
**Concept**: Small VM with inbox/outbox directories.

**How it works**:
- Agent: `scp deps-123.edn vm:/srv/inbox/`
- VM cron processes inbox, uploads .m2, writes outbox
- Agent: `scp vm:/srv/outbox/deps-123.edn .`

**Pros**:
- Simple, time-tested
- SSH usually allowed

**Cons**:
- Requires VM maintenance
- Manual polling

**Best for**: SSH-enabled, HTTP-restricted environments

---

### Pattern 10: Pub/Sub + Sidecar Proxy
**Concept**: Local sidecar handles network complexity.

**How it works**:
- Container 1: Sandboxed agent (no network)
- Container 2: "Network agent" with full access
- Sandbox talks to sidecar via `http://sidecar:8080`
- Sidecar publishes to Pub/Sub
- Cloud Run subscriber processes jobs
- Sidecar exposes results back to sandbox

**Pros**:
- Clean separation of concerns
- Scales beyond one machine
- Security boundary

**Cons**:
- Complex setup
- More moving parts

**Best for**: Production multi-tenant systems

---

## Recommended Approach: GitHub-Based (Pattern 2+)

Given the constraints and the conversation analysis, the **GitHub Actions + Release Assets** pattern emerges as optimal:

### Why GitHub?
- ✅ No `gcloud` required in sandbox
- ✅ No GCS auth problems
- ✅ Free for public repos
- ✅ Generous limits (see docs/github-actions-artifacts.md)
- ✅ Built-in artifact storage
- ✅ Public download URLs via Release assets

### Hybrid Pattern: GitHub Inbox + Release Artifacts

**Architecture**:
1. **Inbox**: Files in Git repo (`deps-requests/*.edn`)
2. **Processor**: GitHub Actions workflow
3. **Storage**: GitHub Release assets (public HTTPS URLs)
4. **Outbox**: Files in Git repo (`deps-responses/*.edn`)

**Flow**:
```
1. Sandbox writes deps-requests/job-123.edn
2. Host commits + pushes to repo
3. GitHub Actions triggers on push
4. Workflow warms .m2, creates tarball
5. Workflow uploads to Release (m2-bundles tag)
6. Workflow writes deps-responses/job-123.edn with URL
7. Host pulls repo
8. Sandbox downloads tarball via curl (no auth!)
9. Host mounts .m2 into sandbox
```

**URL Example**:
```
https://github.com/owner/repo/releases/download/m2-bundles/m2-job-123.tar.gz
```

See `docs/github-architecture.md` for full implementation details.

---

## GCS Security Considerations

If using GCS patterns (3, or hybrid with GCS backend):

### Never Use Public-Write Buckets
- **Risk**: Unlimited cost from abuse
- **Solution**: Use signed URLs, service accounts, or proxy

### Mitigation Strategies

1. **Signed URLs** (time-limited, scope-limited):
   ```bash
   # Generate write URL for single object
   gsutil signurl -d 5m key.json gs://bucket/requests/job-123.json
   ```

2. **Per-job random keys**:
   ```
   requests/123-8f32db10-7694-47e1-9ca0.json
   # Hard to guess, prevents collisions
   ```

3. **Separate buckets**:
   - Control bucket (private): requests/responses
   - Artifacts bucket (public-read): .m2 tarballs

4. **IAM conditions** (prefix-based):
   ```
   Service account can only write to gs://bucket/agent1/*
   ```

5. **Cloud Run/Function proxy**:
   ```
   POST /enqueue → validates → writes to GCS
   # Rate limiting, size checks, auth
   ```

6. **Lifecycle rules**:
   ```
   Delete objects older than 1 day
   ```

7. **Budget alerts**:
   ```
   Alert if storage > $10/day
   ```

8. **Local bridge** (safest):
   ```
   Sandbox → local file → host script → GCS
   # No public bucket needed
   ```

---

## Comparison Matrix

| Pattern | Complexity | Network Needed | Auth | Cost | Latency | Best Use Case |
|---------|-----------|----------------|------|------|---------|---------------|
| 1. Local folder | Low | None | None | Free | Instant | Local dev |
| 2. Git repo | Medium | Git only | GitHub | Free | Minutes | Multi-machine |
| 3. GCS inbox | Medium | GCS | GCS/Signed | $$ | Seconds | Cloud-native |
| 4. REST API | High | HTTP | Custom | $$ | Seconds | API-first |
| 5. Log protocol | Low | None | None | Free | Instant | CLI wrappers |
| 6. Makefile | Low | Varies | Varies | Varies | Manual | Explicit control |
| 7. Sheets | Medium | Google API | Google | Free | Minutes | Visual debug |
| 8. Email | High | SMTP | Email | Free | Minutes | Ultra-restricted |
| 9. SSH VM | Medium | SSH | SSH key | $ | Seconds | SSH-only nets |
| 10. Pub/Sub | High | Full | GCP | $$ | Seconds | Production |

---

## Next Steps

See:
- `docs/github-architecture.md` - Detailed GitHub implementation
- `docs/github-actions-artifacts.md` - GitHub limits and billing
- `plans/implementation-plan.md` - Step-by-step build guide
- `docs/bundle-schema.md` - Bundle manifest format

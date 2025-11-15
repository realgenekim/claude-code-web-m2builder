# M2 Builder Project Summary

## What Was Analyzed

This documentation set was created from a detailed conversation about building a communication system for sandboxed coding agents (Codex CLI, Claude Code) that need to share Maven/Clojure dependency bundles but can't directly access external resources like Maven Central or Google Cloud Storage.

## Key Problem

**Two-agent communication challenge**:
- **Agent A** (sandboxed): No network access, no `gcloud` CLI, can't download from Maven Central
- **Agent B** (networked): Full internet access, can build .m2 caches
- **Need**: A way for Agent A to request dependencies and Agent B to deliver them

## Solution: GitHub-Based Architecture

Use **GitHub as the entire infrastructure**:
1. **Message bus**: Files in Git repo (inbox/outbox pattern)
2. **Build system**: GitHub Actions (networked environment)
3. **Artifact storage**: GitHub Release assets (public HTTPS URLs)

**Key insight**: No GCS, no `gcloud`, no auth complexity—just GitHub.

## Core Innovation: Bundle = Deps Map

**Simple concept**: Each top-level `:deps` key in a `deps.edn` → one prebuilt, downloadable .m2 bundle

**Community model**: Contributors add `bundles/{name}.edn` files defining dependency sets, CI automatically builds and publishes them.

## Documents Created

### 1. `docs/agent-communication-patterns.md`
**Purpose**: Comprehensive analysis of 10 different communication patterns for sandboxed agents

**Contents**:
- 10 patterns from simple (local folders) to complex (Pub/Sub)
- Comparison matrix (complexity, cost, latency)
- Security considerations (especially GCS public-write risks)
- Recommended approach: GitHub-based

**Key takeaway**: GitHub Actions + Release assets is the sweet spot for this use case.

---

### 2. `docs/github-architecture.md`
**Purpose**: Detailed specification of the GitHub-based architecture

**Contents**:
- Architecture diagram (sandbox → host → GitHub → Actions → Releases)
- Detailed flow (request → build → response → download)
- Community bundle model
- Repository structure
- Security model (auth boundaries)
- Cost estimation (public repo = $0/month!)
- Alternative: Artifacts branch for smaller bundles

**Key components**:
- `bundles/` directory: Community-maintained bundle definitions
- `deps-requests/` inbox: Ad-hoc dependency requests
- `deps-responses/` outbox: Build results
- GitHub Actions: Automated .m2 warming
- Release assets: Public download URLs (no auth!)

**Key takeaway**: Public repos get unlimited Actions minutes and storage—use them!

---

### 3. `docs/github-actions-artifacts.md`
**Purpose**: Deep dive into GitHub Actions artifacts and Release assets—limits, billing, access methods

**Contents**:
- **Artifacts**:
  - 5 GB max per artifact
  - 90-day default retention (customizable)
  - Free tier: 500 MB–50 GB depending on plan
  - Public repos: unlimited
  - Paid overage: ~$0.24/GB/month
  - Requires auth for download
- **Release assets**:
  - 2 GB max per file
  - Permanent storage
  - Free for public repos
  - Public download URLs (no auth!)
- **Access methods**:
  - Web UI (manual)
  - `gh` CLI (automation)
  - REST API (custom tooling)
- **Cost examples**: Scenarios from $0/month (public) to ~$0.25/month (private, low usage)

**Key insight**: Use Release assets for distribution (permanent, public, free), artifacts only for temp workflow output.

---

### 4. `docs/bundle-schema.md`
**Purpose**: Formal specification of the EDN format for bundle definitions

**Contents**:
- **Required fields**:
  - `:schema-version` - Future-proofing
  - `:bundle-id` - Unique kebab-case identifier
  - `:version` - Semver
  - `:description` - Human-readable summary
  - `:maintainer` - GitHub handle (`@user`)
  - `:deps` - Clojure tools.deps map
- **Optional fields**:
  - `:tags` - Discoverability
  - `:upstream-url` - Reference docs
  - `:license` - SPDX identifier
  - `:size-estimate-mb` - Download hint
  - `:aliases` - Predefined aliases
- **Validation rules**: Syntax, format, uniqueness, size limits
- **Naming conventions**: `{primary-lib}-{qualifier}`
- **Examples**: Minimal, complex, domain-specific

**Key design**: Each bundle is **just a deps map**—simple, composable, familiar to Clojure devs.

---

### 5. `plans/implementation-plan.md`
**Purpose**: Step-by-step roadmap to build the system

**Contents**:
- **Phase 1** (Week 1): Core infrastructure
  - Bundle schema design ✅
  - Repository structure
  - 3 initial bundles (clojure-core, web-stack, gcs-client)
  - Bundle registry
- **Phase 2** (Week 1-2): GitHub Actions workflows
  - `build-bundle.yml` - Main build workflow
  - `validate-bundle.yml` - PR validation
  - `cleanup.yml` - Housekeeping
- **Phase 3** (Week 2): Client scripts
  - `request-bundle.sh` - Create request
  - `wait-for-bundle.sh` - Poll for response
  - `download-bundle.sh` - Fetch and extract
  - `use-bundle.sh` - All-in-one wrapper
- **Phase 4** (Week 2-3): Documentation & examples
  - README update
  - CONTRIBUTING.md
  - Docker, Makefile, wrapper examples
- **Phase 5** (Week 3): Testing & refinement
  - E2E tests
  - Local testing workflow
  - Performance benchmarks
  - Cost analysis
- **Phase 6** (Week 4, optional): Migration from GCS
  - Dual-mode support
  - Migration script
  - Deprecation timeline

**Acceptance criteria**:
- Must have: Schema, 3 bundles, CI workflow, public URLs, client scripts, docs
- Should have: 10+ bundles, validation, examples, cost docs
- Nice to have: Web UI, composition, versioning, metrics

**Success metrics**: GitHub stars, contributors, bundle count, downloads, build success rate, cost

---

## How These Fit Together

```
User Question: "How do sandboxed agents communicate?"
    ↓
1. Read: agent-communication-patterns.md
   → Understand 10 options, pick GitHub-based approach
    ↓
2. Read: github-architecture.md
   → Understand detailed design, flow, components
    ↓
3. Read: github-actions-artifacts.md
   → Understand limits, costs, how to access artifacts
    ↓
4. Read: bundle-schema.md
   → Understand how to define a bundle
    ↓
5. Read: plans/implementation-plan.md
   → Build it step-by-step
```

## Visual Architecture

```
┌─────────────────┐
│  Sandboxed      │
│  Coding Agent   │  (Codex, Claude Code)
│  (no network)   │
└────────┬────────┘
         │ writes manifest
         ↓
┌─────────────────┐
│  Local Host     │
│  Wrapper        │  (has GitHub auth)
└────────┬────────┘
         │ git push
         ↓
┌─────────────────┐
│  GitHub Repo    │
│  ├── bundles/   │  ← Community definitions
│  ├── requests/  │  ← Inbox
│  └── responses/ │  ← Outbox
└────────┬────────┘
         │ triggers
         ↓
┌─────────────────┐
│  GitHub Actions │
│  Workflow       │  (builds .m2, uploads tarball)
└────────┬────────┘
         │ uploads
         ↓
┌─────────────────┐
│  GitHub Release │
│  Assets         │  (public HTTPS URLs!)
└────────┬────────┘
         │ curl download (no auth)
         ↓
┌─────────────────┐
│  Local Host     │
│  (extracts to   │
│   ~/.m2-cache)  │
└────────┬────────┘
         │ bind mount
         ↓
┌─────────────────┐
│  Sandboxed      │
│  Agent          │  (uses .m2 cache)
└─────────────────┘
```

## Key Insights from Conversation

### 1. "Every top-level deps key → bundle"
This simple mental model makes bundles intuitive for Clojure developers. No new concepts—just "a deps.edn that's prebuilt for you."

### 2. GitHub is the universal answer
When you said "gcloud auth problematic," the conversation pivoted to: **What if we never use GCS at all?** GitHub provides everything:
- Message bus (Git commits)
- Build system (Actions)
- Storage (Releases)
- CDN (GitHub's infrastructure)
- Auth (GitHub tokens)
- **Cost**: $0 for public repos

### 3. Public-write buckets = cost disaster
The conversation explored GCS inbox/outbox and quickly realized: **never** make a bucket public-write. Mitigations:
- Signed URLs (time-limited, scope-limited)
- Proxy with validation (Cloud Run, Cloud Function)
- Local bridge (safest: no public bucket at all)

### 4. Release assets > Artifacts for distribution
- **Artifacts**: Temp build output, requires auth, paid storage
- **Release assets**: Permanent, public URLs, free for public repos
- **Winner**: Promote artifacts to releases

### 5. Bundle composition is client-side
Instead of complex `:extends` or `:includes` in bundle schema, keep bundles simple. Let consumers compose:
```bash
download-bundle.sh clojure-core
download-bundle.sh web-stack
# Merge locally or use Docker layers
```

## Questions Answered

**Original question**: "How do two coding agents communicate when one is sandboxed?"

**10 patterns explored**: Filesystem, Git, GCS, REST API, logs, Makefile, Sheets, email, SSH, Pub/Sub

**Chosen pattern**: GitHub-based (Pattern 2+)

**Why GitHub?**
- ✅ No `gcloud` required
- ✅ No GCS auth complexity
- ✅ Free for public repos
- ✅ Generous limits (2 GB files, unlimited storage/bandwidth)
- ✅ Built-in CI/CD (Actions)
- ✅ Public download URLs (Release assets)
- ✅ Familiar to developers (Git workflow)

**Cost**: $0/month for public repos, ~$0.25/month for private (low usage)

**Trade-offs accepted**:
- Git commits as "messages" (slightly weird but functional)
- CI latency (minutes, not seconds—but acceptable)
- 2 GB file size limit (fine for 99% of bundles)

## What's Next (Per Implementation Plan)

**Immediate next steps**:
1. ✅ Bundle schema defined (done in this session)
2. Create repository structure (`bundles/`, `deps-requests/`, etc.)
3. Define 3 starter bundles (`clojure-core`, `web-stack`, `gcs-client`)
4. Draft GitHub Actions workflow (`.github/workflows/build-bundle.yml`)
5. Test workflow locally or in GitHub
6. First real bundle build!

**Decision needed**:
- Keep repo name `m2builder` or rename to `clojure-m2-bundles`?
- Public or private? (Recommendation: **public** for free everything)
- Personal repo or create GitHub org? (Can move later)

## Resources Referenced in Conversation

- [GitHub Docs: Storing workflow data as artifacts](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
- [GitHub Docs: Billing for GitHub Actions](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)
- [Clojure tools.deps Reference](https://clojure.org/reference/deps_and_cli)
- [Semantic Versioning](https://semver.org/)

## Files in This Documentation Set

```
m2builder/
├── README.md                              (existing - needs update)
├── docs/
│   ├── SUMMARY.md                         (this file)
│   ├── agent-communication-patterns.md    (✅ new)
│   ├── github-architecture.md             (✅ new)
│   ├── github-actions-artifacts.md        (✅ new)
│   └── bundle-schema.md                   (✅ new)
├── plans/
│   └── implementation-plan.md             (✅ new)
├── build-m2-snapshot.sh                   (existing - GCS-based)
└── restore-m2-cache.sh                    (existing - GCS-based)
```

**Status**: Documentation phase complete ✅

**Next**: Implementation phase (see `plans/implementation-plan.md`)

---

## In One Sentence

**We designed a GitHub-native system where community-maintained Clojure dependency bundles are defined as EDN files, automatically built by GitHub Actions, stored as public Release assets, and consumed by sandboxed agents via simple curl downloads—all at zero cost for public repositories.**

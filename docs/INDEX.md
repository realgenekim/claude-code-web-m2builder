# M2 Builder Documentation Index

## Quick Navigation

Start here based on what you want to understand:

### 🎯 "Show me how it works end-to-end"
👉 Read: **[interaction-example.md](interaction-example.md)**
- Concrete timeline of Claude Code Web requesting deps
- Step-by-step with file system states, logs, and sequence diagram
- Shows both ad-hoc requests and prebuilt bundles

### 🏗️ "I want to build this system"
👉 Read: **[implementation-plan.md](../plans/implementation-plan.md)**
- 6-phase rollout plan (4 weeks)
- Acceptance criteria and success metrics
- Immediate next steps

### 🧠 "Why GitHub? What were the alternatives?"
👉 Read: **[agent-communication-patterns.md](agent-communication-patterns.md)**
- 10 communication patterns evaluated
- Comparison matrix (complexity, cost, latency)
- Security considerations (why not public-write GCS buckets?)

### 📐 "How does the GitHub architecture work?"
👉 Read: **[github-architecture.md](github-architecture.md)**
- Architecture diagram
- Detailed flow (request → build → response → download)
- Community bundle model
- Repository structure
- Cost estimation ($0 for public repos!)

### 💰 "What are the GitHub limits and costs?"
👉 Read: **[github-actions-artifacts.md](github-actions-artifacts.md)**
- Artifact limits (5 GB per file, 90-day retention)
- Release asset limits (2 GB per file, permanent)
- Free tier quotas (500 MB–50 GB storage depending on plan)
- Billing examples ($0 for public, ~$0.25/month for private low usage)
- How to access artifacts (Web UI, `gh` CLI, REST API)

### 📋 "How do I define a bundle?"
👉 Read: **[bundle-schema.md](bundle-schema.md)**
- EDN format specification
- Required fields (`:bundle-id`, `:version`, `:deps`, etc.)
- Optional fields (`:tags`, `:aliases`, `:size-estimate-mb`, etc.)
- Validation rules
- Naming conventions
- Examples (minimal, complex, domain-specific)

### 📖 "Give me the executive summary"
👉 Read: **[SUMMARY.md](SUMMARY.md)**
- What problem was solved
- Solution overview
- Key insights from the conversation
- Document roadmap
- One-sentence summary

---

## Document Map

```
m2builder/
│
├── docs/
│   ├── INDEX.md (this file)                     ⭐ START HERE
│   │
│   ├── SUMMARY.md                               📖 Executive summary
│   │   └─→ High-level overview of all docs
│   │
│   ├── interaction-example.md                   🎬 Concrete walkthrough
│   │   ├─→ Timeline: Claude requests → GitHub builds → Claude compiles
│   │   ├─→ File system states at each stage
│   │   ├─→ Terminal logs and GitHub Actions output
│   │   └─→ Sequence diagram
│   │
│   ├── agent-communication-patterns.md          🔍 Design exploration
│   │   ├─→ 10 communication patterns evaluated
│   │   ├─→ Comparison matrix
│   │   ├─→ Security considerations (GCS risks)
│   │   └─→ Why GitHub won
│   │
│   ├── github-architecture.md                   🏗️ Detailed design
│   │   ├─→ Architecture diagram
│   │   ├─→ Flow (6 steps from request to use)
│   │   ├─→ Community bundle model
│   │   ├─→ Repository structure
│   │   ├─→ Security model
│   │   ├─→ Cost estimation
│   │   └─→ Alternative: artifacts branch
│   │
│   ├── github-actions-artifacts.md              💰 Limits & billing
│   │   ├─→ Artifact limits (5 GB, 90-day default)
│   │   ├─→ Release asset limits (2 GB, permanent)
│   │   ├─→ Free tier quotas (500 MB–50 GB)
│   │   ├─→ Paid pricing ($0.24/GB/month)
│   │   ├─→ Access methods (gh CLI, API, Web UI)
│   │   └─→ FAQ
│   │
│   └── bundle-schema.md                         📋 EDN specification
│       ├─→ Schema version 1.0.0
│       ├─→ Required fields
│       ├─→ Optional fields
│       ├─→ Validation rules
│       ├─→ Naming conventions
│       ├─→ Examples
│       └─→ Migration & versioning
│
└── plans/
    └── implementation-plan.md                   🚀 Build roadmap
        ├─→ Current state analysis
        ├─→ Phase 1: Core infrastructure (Week 1)
        ├─→ Phase 2: GitHub Actions workflows (Week 1-2)
        ├─→ Phase 3: Client scripts (Week 2)
        ├─→ Phase 4: Documentation & examples (Week 2-3)
        ├─→ Phase 5: Testing & refinement (Week 3)
        ├─→ Phase 6: Migration from GCS (Week 4, optional)
        ├─→ Acceptance criteria
        ├─→ Success metrics
        └─→ Risk mitigation
```

---

## Reading Paths

### Path 1: "I'm a user who wants to understand this quickly"
1. [SUMMARY.md](SUMMARY.md) - Get the gist (5 min)
2. [interaction-example.md](interaction-example.md) - See it in action (10 min)
3. **Done!** You now understand the system.

### Path 2: "I'm a contributor who wants to add bundles"
1. [bundle-schema.md](bundle-schema.md) - Learn EDN format (10 min)
2. [implementation-plan.md](../plans/implementation-plan.md) - Phase 1.3 (initial bundles) (5 min)
3. **Ready!** Create your bundle EDN and open a PR.

### Path 3: "I'm an implementer building this system"
1. [SUMMARY.md](SUMMARY.md) - Context (5 min)
2. [github-architecture.md](github-architecture.md) - Understand design (20 min)
3. [bundle-schema.md](bundle-schema.md) - Schema spec (10 min)
4. [implementation-plan.md](../plans/implementation-plan.md) - Follow phases (30 min)
5. [github-actions-artifacts.md](github-actions-artifacts.md) - Reference as needed
6. **Building!** Work through Phase 1 → 2 → 3 → 4 → 5.

### Path 4: "I'm a decision-maker evaluating costs and feasibility"
1. [SUMMARY.md](SUMMARY.md) - Problem & solution (5 min)
2. [agent-communication-patterns.md](agent-communication-patterns.md) - Alternatives considered (10 min)
3. [github-actions-artifacts.md](github-actions-artifacts.md) - Limits & billing (15 min)
4. [github-architecture.md](github-architecture.md) - Cost estimation section (5 min)
5. **Decided!** Public repo = $0/month, private = ~$0.25/month for typical usage.

### Path 5: "I'm debugging why my bundle request isn't working"
1. [interaction-example.md](interaction-example.md) - Compare your logs to expected flow (10 min)
2. [github-architecture.md](github-architecture.md) - Verify file locations (5 min)
3. [implementation-plan.md](../plans/implementation-plan.md) - Phase 2 (workflows) for CI debugging (10 min)
4. **Fixed!** (hopefully)

---

## Key Concepts Glossary

**Bundle**: A prewarmed .m2 Maven cache containing a curated set of dependencies, packaged as a `.tar.gz` and distributed via GitHub Releases.

**Bundle definition**: An EDN file (e.g., `bundles/web-stack.edn`) that specifies `:deps` and metadata. GitHub Actions reads this to build the bundle.

**Bundle ID**: Unique kebab-case identifier (e.g., `web-stack`, `clojure-core`). Used in filenames, URLs, and references.

**Mailbox pattern**: Communication via files in Git repo:
- **Inbox**: `deps-requests/` (agents write here)
- **Outbox**: `deps-responses/` (CI writes here)

**Request**: EDN file in `deps-requests/` saying "I need these deps." Triggers GitHub Actions to build a bundle.

**Response**: EDN file in `deps-responses/` saying "Your bundle is ready at this URL."

**Release asset**: File attached to a GitHub Release. For public repos, has a public HTTPS URL that requires no authentication to download.

**Artifact** (GitHub Actions): Temporary file produced by a workflow run. Expires after 1–400 days. Requires authentication to download.

**Sandboxed agent**: Coding assistant (Codex CLI, Claude Code Web) running in a restricted environment with limited or no network access.

**Networked agent**: GitHub Actions runner (or local helper) with full internet access. Can download from Maven Central.

**Local wrapper**: Script (`m2-helper.sh`) running on your laptop that monitors the sandbox's requests, pushes to GitHub, and downloads responses.

**Community bundle**: Prebuilt bundle defined in `bundles/` that anyone can use. Examples: `clojure-core`, `web-stack`, `google-cloud-storage`.

**Ad-hoc request**: Custom dependency set requested via `deps-requests/` that isn't a prebuilt community bundle. GitHub Actions builds it on-demand.

---

## Visual Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     THE BIG PICTURE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Problem: Sandboxed agent needs Maven deps, can't access net   │
│                                                                 │
│  Solution:                                                      │
│    1. Agent writes request → shared folder                     │
│    2. Wrapper commits → GitHub repo                            │
│    3. GitHub Actions builds .m2 tarball                        │
│    4. Actions uploads → Release (public URL)                   │
│    5. Wrapper downloads & extracts → shared folder             │
│    6. Agent uses .m2 cache → compiles successfully             │
│                                                                 │
│  Cost: $0 for public repos, ~$0.25/month for private           │
│  Time: ~3 min first request, ~30 sec for prebuilt bundles      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## FAQ

### Q: Which doc should I read first?
**A**: [SUMMARY.md](SUMMARY.md) for the overview, then [interaction-example.md](interaction-example.md) to see it in action.

### Q: I just want to use this system. Where's the user guide?
**A**: Not built yet! See [implementation-plan.md](../plans/implementation-plan.md) Phase 4 for planned user documentation. For now, [interaction-example.md](interaction-example.md) shows the usage pattern.

### Q: I want to add a bundle. How?
**A**: See [bundle-schema.md](bundle-schema.md) for the EDN format, then look at [implementation-plan.md](../plans/implementation-plan.md) Phase 1.3 for examples. (Full PR workflow in Phase 4's CONTRIBUTING.md, not yet written.)

### Q: What if I need a dependency that's not in a bundle?
**A**: Create an ad-hoc request in `deps-requests/` with your custom `:deps` map. GitHub Actions will build it on-demand. See [interaction-example.md](interaction-example.md) T+0:01.

### Q: How much will this cost me?
**A**: See [github-actions-artifacts.md](github-actions-artifacts.md) Cost Examples section. TL;DR: $0 for public repos.

### Q: Can I use this with private repos?
**A**: Yes, but Release assets won't have public download URLs (require auth). See [github-architecture.md](github-architecture.md) Security Model section.

### Q: Why not just use Docker images with .m2 preinstalled?
**A**: That works too! This system is for environments where:
- Pulling Docker images is slow/restricted
- You need fine-grained control over deps
- You want a community-curated bundle library
- Tarballs are easier than image layers

### Q: Can I compose multiple bundles?
**A**: Not natively in v1.0.0. See [bundle-schema.md](bundle-schema.md) FAQ. You can merge bundles client-side (download both, combine `.m2` directories).

### Q: What if Maven Central is down?
**A**: GitHub Actions build will fail. Retry when it's back, or use a mirror (configure in `:mvn/repos` in deps.edn, future feature).

### Q: Who maintains the community bundles?
**A**: Each bundle has a `:maintainer` field (GitHub handle). See [bundle-schema.md](bundle-schema.md) Required Fields section.

---

## Contribution Guide (Future)

Not yet written. Will be in `CONTRIBUTING.md` after Phase 4 (see [implementation-plan.md](../plans/implementation-plan.md)).

**For now**:
1. Read [bundle-schema.md](bundle-schema.md)
2. Create a bundle EDN file
3. Test locally (script TBD in Phase 3)
4. Open a PR
5. Wait for validation workflow (Phase 2)
6. Maintainer merges → CI builds → Release asset created

---

## References

**External docs**:
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Clojure tools.deps Reference](https://clojure.org/reference/deps_and_cli)
- [Semantic Versioning](https://semver.org/)

**Internal docs**:
- See document map above ☝️

---

## Document Stats

| Document | Size | Reading Time | Audience |
|----------|------|--------------|----------|
| SUMMARY.md | 12 KB | 5 min | Everyone |
| interaction-example.md | 22 KB | 15 min | Users, implementers |
| agent-communication-patterns.md | 10 KB | 10 min | Architects, decision-makers |
| github-architecture.md | 18 KB | 20 min | Implementers, architects |
| github-actions-artifacts.md | 15 KB | 15 min | Implementers, decision-makers |
| bundle-schema.md | 14 KB | 15 min | Contributors, implementers |
| implementation-plan.md | 21 KB | 30 min | Implementers |
| **Total** | **112 KB** | **~2 hours** | |

---

## Next Steps

After reading these docs:

**If you're building this**:
→ Go to [implementation-plan.md](../plans/implementation-plan.md) and start Phase 1

**If you're using this**:
→ Wait for MVP (or help build it!)

**If you're contributing bundles**:
→ Read [bundle-schema.md](bundle-schema.md) and create a PR

**If you're evaluating feasibility**:
→ Review cost analysis in [github-actions-artifacts.md](github-actions-artifacts.md)

**If you have questions**:
→ Open a GitHub issue (after this repo goes public)

---

## Credits

**Original conversation**: ChatGPT & @realgenekim (2025-11-15)

**Documentation**: Generated by Claude Code (Sonnet 4.5) from conversation analysis

**Inspiration**: The challenge of enabling sandboxed coding agents to share dependencies without complex infrastructure

**License**: TBD (likely EPL-1.0 or MIT to match Clojure ecosystem)

---

**Last updated**: 2025-11-15

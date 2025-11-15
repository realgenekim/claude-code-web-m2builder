# Claude Branch Communication Pattern

## The Constraint is the Feature! 🎯

**Discovery**: Claude Code Web can only create branches starting with `claude/` (e.g., `claude/server2-m2-gcs-setup-01Evyyikdm39H5ZyjWAZraxr`)

**Insight**: This isn't a limitation—it's the perfect communication mechanism for sandboxed agents!

## How It Works

### Traditional Approach (Files in Main Branch)
❌ Problems:
- Requires commit access to main branch
- Clutters commit history with "request" commits
- Hard to track which requests are pending vs. completed
- Merge conflicts if multiple agents request simultaneously

### Claude Branch Approach (Branches as Messages)
✅ Advantages:
- **Each request = one branch** (isolated, no conflicts)
- **Branch name encodes metadata** (agent ID, timestamp, request type)
- **GitHub Actions triggers on branch push**
- **Pull request = conversation thread** (comments, status updates)
- **Merge = completion** (clean history, atomic)
- **Automatic cleanup** (delete branch after merge)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  SANDBOXED AGENT (Claude Code Web)                         │
│  Can only create branches: claude/*                        │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ 1. Create branch: claude/bundle-request-gcs-client-ABC123
                    │ 2. Add: bundles/gcs-client.edn (or request file)
                    │ 3. Push branch
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│  GITHUB REPOSITORY                                          │
│  Branches:                                                  │
│  - main                                                     │
│  - claude/bundle-request-gcs-client-ABC123 ← NEW           │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ 3. Branch push triggers workflow
                    ▼
┌─────────────────────────────────────────────────────────────┐
│  GITHUB ACTIONS (.github/workflows/build-from-branch.yml)  │
│                                                             │
│  Triggers on: push to claude/bundle-request-*              │
│                                                             │
│  Steps:                                                    │
│  1. Detect bundle request from branch name or files        │
│  2. Build M2 cache                                         │
│  3. Create tarball                                         │
│  4. Upload to Release as asset                             │
│  5. Create PR with download URL in description             │
│  6. Comment on PR: "✅ Bundle ready! Download: [URL]"      │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ 4. PR created automatically
                    ▼
┌─────────────────────────────────────────────────────────────┐
│  PULL REQUEST                                               │
│  Title: "Bundle Request: gcs-client"                       │
│  Branch: claude/bundle-request-gcs-client-ABC123 → main   │
│                                                             │
│  Description:                                              │
│  - Requested by: Claude Code Web                          │
│  - Bundle: gcs-client                                      │
│  - Status: ✅ Built                                        │
│  - Download: https://github.com/.../m2-gcs-client.tar.gz   │
│                                                             │
│  Comments:                                                 │
│  - github-actions[bot]: Bundle built in 12s (47 MB)       │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ 5. Claude sees PR notification
                    │    (or polls for PR with label)
                    ▼
┌─────────────────────────────────────────────────────────────┐
│  SANDBOXED AGENT (Claude Code Web)                         │
│  Reads PR description, extracts download URL               │
│  Downloads bundle, uses it                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Branch Naming Convention

**Format**: `claude/bundle-request-{bundle-id}-{timestamp}`

**Examples**:
- `claude/bundle-request-gcs-client-20251115-103045`
- `claude/bundle-request-web-stack-01Evyyikdm39H5ZyjWAZraxr`
- `claude/bundle-request-custom-deps-ABC123`

**Metadata Encoded in Branch Name**:
- `claude/` = Created by Claude agent (required prefix)
- `bundle-request-` = Request type (could also be `bundle-feedback-`, `bundle-test-`, etc.)
- `{bundle-id}` = Which bundle is being requested
- `{timestamp}` = Unique identifier (prevents collisions)

**Why this works**:
- Branch name is self-documenting
- Easy to filter in GitHub Actions: `if: startsWith(github.ref, 'refs/heads/claude/bundle-request-')`
- No need to parse file contents to understand request
- GitHub UI groups branches by prefix

---

## Workflow Implementation

### Trigger on Claude Branches

```yaml
name: Build M2 Bundle from Branch

on:
  push:
    branches:
      - 'claude/bundle-request-*'
      - 'claude/custom-deps-*'

jobs:
  build-and-respond:
    runs-on: ubuntu-latest
    steps:
      - name: Extract bundle ID from branch name
        id: meta
        run: |
          BRANCH_NAME="${{ github.ref_name }}"
          # claude/bundle-request-gcs-client-ABC123 → gcs-client
          BUNDLE_ID=$(echo "$BRANCH_NAME" | sed 's/claude\/bundle-request-\(.*\)-[^-]*$/\1/')
          echo "bundle-id=$BUNDLE_ID" >> $GITHUB_OUTPUT

      - name: Check if bundle exists
        run: |
          if [ -f "bundles/${{ steps.meta.outputs.bundle-id }}.edn" ]; then
            echo "Bundle definition found!"
          else
            echo "No bundle definition - checking for custom deps in branch..."
          fi

      - name: Build bundle
        # ... (same as before)

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v6
        with:
          branch: ${{ github.ref_name }}
          base: main
          title: "Bundle Request: ${{ steps.meta.outputs.bundle-id }}"
          body: |
            ## 🤖 Automated Bundle Build

            **Requested by**: Claude Code Web
            **Bundle ID**: `${{ steps.meta.outputs.bundle-id }}`
            **Status**: ✅ Built successfully

            ### Download

            ```bash
            curl -L -O https://github.com/${{ github.repository }}/releases/download/m2-bundles/m2-${{ steps.meta.outputs.bundle-id }}.tar.gz
            ```

            ### Statistics
            - Build time: ${{ steps.build.outputs.duration }}s
            - Size (compressed): ${{ steps.build.outputs.size-mb }} MB
            - JAR files: ${{ steps.build.outputs.artifact-count }}

            ### Usage
            ```bash
            tar xzf m2-${{ steps.meta.outputs.bundle-id }}.tar.gz -C ~/.m2-cache/
            clojure -Sdeps '{:mvn/local-repo "~/.m2-cache/m2-${{ steps.meta.outputs.bundle-id }}"}' ...
            ```

            ---
            *Auto-generated by GitHub Actions*
          labels: |
            claude-request
            bundle-built
```

---

## Communication Flow Types

### Type 1: Predefined Bundle Request

**Claude creates**:
- Branch: `claude/bundle-request-gcs-client-ABC123`
- (Optional) File: `requests/gcs-client-request.txt` with notes

**Workflow**:
1. Detects bundle ID from branch name: `gcs-client`
2. Looks up `bundles/gcs-client.edn`
3. Builds from existing definition
4. Creates PR with download URL

**Claude gets**:
- PR notification
- Download URL in PR description
- Can comment on PR if issues

---

### Type 2: Custom Dependencies (Ad-hoc)

**Claude creates**:
- Branch: `claude/custom-deps-my-project-ABC123`
- File: `custom-deps/my-project-ABC123.edn` with custom `:deps` map

**Workflow**:
1. Detects `custom-deps/` prefix
2. Reads `.edn` file from branch
3. Builds bundle from custom deps
4. Creates PR with download URL
5. Optionally: Suggests adding to `bundles/` as reusable bundle

**Claude gets**:
- One-off bundle for specific needs
- Option to promote to permanent bundle

---

### Type 3: Bundle Composition

**Claude creates**:
- Branch: `claude/compose-bundles-web-db-ABC123`
- File: `compose/web-db-ABC123.edn`:
  ```clojure
  {:compose ["web-stack" "database-stack"]
   :extra-deps {my/lib {:mvn/version "1.0.0"}}}
  ```

**Workflow**:
1. Reads composition spec
2. Merges multiple bundles
3. Adds extra deps
4. Builds combined bundle
5. Creates PR

---

## Advantages Over File-Based Inbox

| Aspect | File-Based Inbox | Claude Branch Pattern |
|--------|------------------|----------------------|
| **Isolation** | Files in main branch (conflicts possible) | Each request = separate branch (no conflicts) |
| **Discovery** | Poll `deps-requests/` folder | GitHub PR notifications or label queries |
| **Conversation** | Separate response file | PR comments (threaded discussion) |
| **Cleanup** | Manual deletion of old files | Auto-delete branch after merge |
| **Status** | File existence check | PR state (open/merged/closed) |
| **History** | Cluttered commit log | Clean PR history, mergeable records |
| **Atomic** | Multi-step (request → response) | Single PR (request → build → merge) |

---

## Claude Code Web Integration

### How Claude Uses This

**Step 1: Create Request Branch**
```bash
# Claude Code Web does this automatically when you say:
# "I need Google Cloud Storage dependencies"

git checkout -b claude/bundle-request-gcs-client-$(date +%s)
# Optional: Add request metadata
echo '{"notes": "Need GCS for my project"}' > requests/gcs-client.txt
git add requests/
git commit -m "Request: GCS bundle"
git push origin HEAD
```

**Step 2: Wait for PR**
Claude polls GitHub API:
```bash
gh pr list --label claude-request --state open --json number,title,body
```

Or GitHub notifies Claude via webhook (if configured).

**Step 3: Extract Download URL from PR**
Parse PR body:
```bash
gh pr view 123 --json body -q '.body' | grep -o 'https://.*m2-.*\.tar\.gz'
```

**Step 4: Download and Use**
```bash
curl -L -O [URL from PR]
tar xzf m2-*.tar.gz -C ~/.m2-cache/
```

---

## Workflow Enhancements

### Auto-Merge After Success

```yaml
- name: Auto-merge PR
  if: success()
  run: |
    gh pr merge ${{ github.event.pull_request.number }} \
      --auto --squash \
      --body "Bundle built and uploaded successfully"
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Label-Based Routing

```yaml
- name: Add status labels
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.issues.addLabels({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.payload.pull_request.number,
        labels: ['claude-request', 'bundle-built', 'ready-to-merge']
      });
```

### Notification Comments

```yaml
- name: Notify Claude
  run: |
    gh pr comment ${{ github.event.pull_request.number }} \
      --body "✅ @claude Your bundle is ready! Download URL in PR description."
```

---

## Security Considerations

### Branch Protection Rules

**Protect main branch**:
- Require PR reviews: No (for auto-merge)
- Require status checks: Yes (bundle build must pass)
- Restrict who can push: Yes (no direct pushes)

**Allow claude/ branches**:
- No restrictions (Claude can create freely)
- Workflow validates contents
- PR required to merge to main

### Validation in Workflow

```yaml
- name: Validate bundle request
  run: |
    # Check file size limits
    MAX_SIZE_MB=2000
    if [ -f "bundles/*.edn" ]; then
      # Validate EDN syntax
      # Check for malicious content
      # Ensure deps are from trusted repos only
    fi
```

---

## Example: End-to-End Flow

**User**: "Claude, I need Google Cloud Storage dependencies"

**Claude Code Web**:
1. Creates branch: `claude/bundle-request-gcs-client-1731682801`
2. Pushes branch
3. Monitors for PR creation

**GitHub Actions** (30 seconds later):
1. Detects branch push
2. Extracts bundle ID: `gcs-client`
3. Builds bundle (12 seconds)
4. Uploads to Release: `m2-gcs-client.tar.gz` (47 MB)
5. Creates PR #1 with download URL
6. Comments: "✅ Bundle ready!"

**Claude Code Web** (polls every 10s):
1. Finds PR #1 with label `claude-request`
2. Reads PR body, extracts URL
3. Downloads tarball
4. Extracts to `~/.m2-cache/m2-gcs-client/`
5. Configures Clojure to use it
6. Replies to user: "✅ Dependencies ready! Compiling your project..."

**Total time**: ~60 seconds from request to ready

---

## Migration Plan

### Phase 1: Add Branch-Based Workflow (alongside existing)
- Keep current file-based approach working
- Add new workflow: `.github/workflows/build-from-branch.yml`
- Test with claude/ branches

### Phase 2: Prefer Branch-Based
- Update docs to recommend branch approach
- Keep file-based as fallback

### Phase 3: Branch-Only
- Remove file-based inbox/outbox
- Cleaner architecture

---

## Conclusion

**The `claude/` branch constraint is actually perfect for this use case!**

Benefits:
1. ✅ Built-in isolation (branches)
2. ✅ Natural conversation (PRs)
3. ✅ Clean history (merge = atomic completion)
4. ✅ Status tracking (PR state)
5. ✅ Notifications (GitHub PR alerts)
6. ✅ No file clutter (branches are cheap)

**Next**: Implement `.github/workflows/build-from-branch.yml` to handle `claude/bundle-request-*` pushes.

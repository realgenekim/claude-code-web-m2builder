# GitHub Actions & Artifacts: Limits and Billing

## What Are GitHub Actions Artifacts?

**Official feature**: Workflow artifacts in GitHub Actions
- Created with `actions/upload-artifact@v4`
- Retrieved with `actions/download-artifact@v4`
- Persist files produced during workflow runs
- Can be passed between jobs or downloaded after run completes

**Perfect for**: Build outputs, test results, compiled binaries, **M2 tarballs**

## Artifact Limits

### Size Limits
| Limit | Value | Notes |
|-------|-------|-------|
| Max artifact size | 5 GB | Per individual artifact [GitHub Docs] |
| Max artifacts per job | 500 | Plenty for typical use cases [GitHub] |
| Max artifact name length | 256 chars | Including path separators |

**For M2 bundles**:
- Most Clojure projects: 50-500 MB compressed → ✅ Well under 5 GB limit
- Large projects (Google Cloud, AWS SDKs): 1-2 GB → ✅ Still OK
- If you hit 5 GB: Split into multiple artifacts (m2-part1, m2-part2, etc.)

### Retention Period
| Setting | Default | Customizable | Max |
|---------|---------|--------------|-----|
| Artifacts | 90 days | Yes, per artifact | 400 days (Enterprise) |
| Logs | 90 days | Yes, repo/org-wide | 400 days |

**Control retention**:
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: m2-bundle
    path: m2-bundle.tar.gz
    retention-days: 3  # Override default
```

**Org/repo-wide setting**:
- Settings → Actions → General → Artifact and log retention
- Set to 1-7 days to minimize storage costs

**For M2 bundles**: Use short retention (1-3 days) since bundles should be promoted to Releases for long-term storage.

---

## Storage & Billing

### Free Tier Quotas

**Actions storage** (artifacts + packages, per account):

| Plan | Free Storage | Free Minutes/Month |
|------|--------------|-------------------|
| GitHub Free (personal) | 500 MB | 2,000 |
| GitHub Pro | 1 GB | 3,000 |
| GitHub Free (org) | 500 MB | 2,000 |
| GitHub Team | 2 GB | 3,000 |
| GitHub Enterprise Cloud | 50 GB | 50,000 |

[Source: GitHub Docs - Billing for Actions]

**Important notes**:
- Storage quota is **account-wide**, shared across all private repos
- Public repos: **Unlimited storage and minutes** for artifacts [GitHub Community]
- Quotas apply to **private repos only**

### Paid Pricing (Beyond Free Tier)

**Storage overage**:
- **$0.008/GB/day** (calculated as GB-hours, charged monthly)
- Roughly **~$0.24/GB/month** (0.008 × 30 days)

[Source: GitHub Docs - Billing for Actions]

**How billing works**:
- Charged based on average storage over time (GB-hours)
- Example: 1 GB artifact stored for 15 days = ~$0.12
- Deleting artifacts stops future charges but doesn't refund already-accrued GB-hours
- Billed monthly, rounded to nearest cent

**Minutes overage** (not relevant for storage, but for completeness):
- Linux runners: $0.008/minute
- Windows: $0.016/minute
- macOS: $0.08/minute

### Cost Examples for M2 Bundles

**Scenario 1: Public repo**
- Artifacts: Unlimited
- **Cost: $0/month**
- **Recommendation**: Use for community bundles

**Scenario 2: Private repo, low usage**
- 5 bundles/week × 200 MB avg = 1 GB/week
- Use 3-day retention → ~430 MB average storage
- Under 500 MB free tier
- **Cost: $0/month**

**Scenario 3: Private repo, moderate usage**
- 10 bundles/day × 150 MB avg = 1.5 GB/day
- Use 1-day retention → ~1.5 GB average storage
- Overage: 1.5 GB - 0.5 GB (free) = 1 GB
- 1 GB × $0.24/month = **$0.24/month**

**Scenario 4: Private repo, heavy usage (bad practice)**
- 20 bundles/day × 300 MB = 6 GB/day
- Use default 90-day retention (don't do this!)
- Average storage: ~540 GB
- Overage: 540 GB × $0.24/month = **$130/month** 😱
- **Fix**: Use 1-day retention → ~6 GB → $1.32/month

**Key insight**: Retention is the killer. Short retention = minimal cost.

---

## Accessing Artifacts Outside Actions

### 1. GitHub Web UI
**Steps**:
1. Go to repo → Actions tab
2. Select workflow run
3. Scroll to "Artifacts" section at bottom
4. Click artifact name → browser downloads a .zip

**Use case**: Manual inspection, debugging

---

### 2. GitHub CLI (`gh`)

**Install**:
```bash
# macOS
brew install gh

# Linux
curl -sS https://webi.sh/gh | sh

# Windows
winget install GitHub.cli
```

**Auth** (one-time):
```bash
gh auth login
# Follow prompts, choose HTTPS + web browser flow
```

**List runs**:
```bash
gh run list --repo owner/repo --limit 10

# Output:
# ✓  Build M2 Bundle  main  1234567890  2m 30s ago
```

**Download artifact**:
```bash
# Download all artifacts from run
gh run download 1234567890 -D ./artifacts

# Download specific artifact by name
gh run download 1234567890 -n m2-bundle -D ./artifacts

# Latest run
gh run download $(gh run list --limit 1 --json databaseId -q '.[0].databaseId') -n m2-bundle
```

**Use case**: Automation, scripts, CI/CD pipelines

**Example wrapper script**:
```bash
#!/usr/bin/env bash
# fetch-latest-bundle.sh

REPO="owner/m2-bundles"
ARTIFACT_NAME="m2-web-stack"

echo "Fetching latest $ARTIFACT_NAME from $REPO..."

RUN_ID=$(gh run list --repo "$REPO" --workflow build-bundle.yml --limit 1 --json databaseId -q '.[0].databaseId')

if [ -z "$RUN_ID" ]; then
  echo "No runs found"
  exit 1
fi

gh run download "$RUN_ID" -n "$ARTIFACT_NAME" -D /tmp/m2-bundle --repo "$REPO"
tar xzf /tmp/m2-bundle/*.tar.gz -C ~/.m2-cache/

echo "Bundle ready at ~/.m2-cache/m2-$ARTIFACT_NAME"
```

---

### 3. GitHub REST API

**Endpoints**:

1. **List artifacts for a run**:
   ```bash
   curl -H "Authorization: Bearer $GITHUB_TOKEN" \
        https://api.github.com/repos/OWNER/REPO/actions/runs/RUN_ID/artifacts
   ```

   **Response**:
   ```json
   {
     "artifacts": [
       {
         "id": 123456789,
         "name": "m2-bundle",
         "size_in_bytes": 209715200,
         "url": "https://api.github.com/repos/OWNER/REPO/actions/artifacts/123456789",
         "archive_download_url": "https://api.github.com/repos/OWNER/REPO/actions/artifacts/123456789/zip"
       }
     ]
   }
   ```

2. **Download artifact**:
   ```bash
   curl -L \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -o artifact.zip \
        https://api.github.com/repos/OWNER/REPO/actions/artifacts/ARTIFACT_ID/zip
   ```

   **Important**: Returns a .zip, even if you uploaded a .tar.gz
   ```bash
   unzip artifact.zip
   tar xzf m2-bundle.tar.gz -C ~/.m2-cache/
   ```

**Use case**: Custom tooling, integrations with non-GitHub systems

---

## Artifacts vs. Release Assets

| Feature | Artifacts | Release Assets |
|---------|-----------|----------------|
| **Purpose** | Temporary build outputs | Permanent release files |
| **Max file size** | 5 GB | 2 GB |
| **Retention** | 90 days default (1-400) | Permanent |
| **Public URL** | ❌ No (requires auth) | ✅ Yes (for public repos) |
| **Download auth** | Always required | Not required (public repos) |
| **Storage limit** | Account quota (500 MB-50 GB) | Unlimited |
| **API** | Actions API | Releases API |
| **Created by** | Workflows | Manual or workflow |
| **Best for** | Passing data between jobs, temp storage | Long-term distribution |

**For M2 bundles**:
- ✅ **Artifacts**: Build output from workflow (short-term)
- ✅ **Release Assets**: Final bundles for distribution (long-term)

**Recommended flow**:
1. Workflow creates artifact (m2-bundle)
2. Workflow promotes artifact to Release asset
3. Artifact expires after 1-3 days
4. Release asset persists forever
5. Users download from Release (no auth for public repos)

---

## Creating Public URLs: Artifacts → Release Assets

**Problem**: Artifacts always require auth, even in public repos.

**Solution**: Promote artifacts to Release assets for public access.

### Method 1: `softprops/action-gh-release`

**Workflow**:
```yaml
- name: Build M2 tarball
  run: |
    tar czf m2-web-stack.tar.gz -C /tmp m2-web-stack

- name: Upload to Release
  uses: softprops/action-gh-release@v1
  with:
    tag_name: m2-bundles
    files: m2-web-stack.tar.gz
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Result**:
```
https://github.com/owner/repo/releases/download/m2-bundles/m2-web-stack.tar.gz
```

**Public download** (no auth):
```bash
curl -L -O https://github.com/owner/repo/releases/download/m2-bundles/m2-web-stack.tar.gz
```

---

### Method 2: `gh` CLI in Workflow

**Workflow**:
```yaml
- name: Build M2 tarball
  run: |
    tar czf m2-web-stack.tar.gz -C /tmp m2-web-stack

- name: Upload to Release
  run: |
    gh release upload m2-bundles m2-web-stack.tar.gz --clobber
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Flags**:
- `--clobber`: Overwrite existing asset with same name
- Useful for "rolling latest" bundles

---

### Method 3: Releases API

**Workflow**:
```yaml
- name: Upload to Release
  run: |
    # Get release ID
    RELEASE_ID=$(curl -s -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
      https://api.github.com/repos/${{ github.repository }}/releases/tags/m2-bundles \
      | jq -r .id)

    # Upload asset
    curl -X POST \
      -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
      -H "Content-Type: application/gzip" \
      --data-binary @m2-web-stack.tar.gz \
      "https://uploads.github.com/repos/${{ github.repository }}/releases/$RELEASE_ID/assets?name=m2-web-stack.tar.gz"
```

---

## Release Assets: Limits & Billing

### Limits
| Limit | Value |
|-------|-------|
| Max file size | 2 GB |
| Total size per release | Unlimited |
| Total releases | Unlimited |

**For M2 bundles**:
- Most bundles: 50-500 MB → ✅ Well under 2 GB
- Very large bundles (1-2 GB) → ✅ Still OK
- If you hit 2 GB: Split into parts or use Git LFS

### Billing
**Storage**: Free (counted as part of Git LFS/bandwidth quota)

**Bandwidth**:
- **Public repos**: Generous soft limit (~1 TB/month, varies)
- **Private repos**: Same as LFS bandwidth quota

**Cost**: Effectively **free** for typical use cases

**Compared to artifacts**:
- Artifacts: Limited by account quota, paid overages
- Releases: Unlimited size, free for public repos
- **Winner for long-term storage**: Releases

---

## Recommendations for M2 Bundles

### For Public Community Bundles
1. **Use public repo** → free everything
2. **Store bundles as Release assets** → permanent, public URLs
3. **Keep artifacts minimal** (1-day retention) → just for temp workflow output
4. **Cost**: $0/month

**Example flow**:
```yaml
- name: Build M2
  run: tar czf m2-bundle.tar.gz ...

- name: Upload artifact (temp)
  uses: actions/upload-artifact@v4
  with:
    name: m2-bundle
    path: m2-bundle.tar.gz
    retention-days: 1

- name: Promote to Release (permanent)
  uses: softprops/action-gh-release@v1
  with:
    tag_name: m2-bundles
    files: m2-bundle.tar.gz
```

---

### For Private Org Bundles
1. **Use private repo**
2. **Set artifact retention to 1-3 days**
3. **Promote to Releases** for bundles that need long-term storage
4. **Monitor storage** via Settings → Billing

**Example cost** (10 devs, 5 bundles/day, 200 MB avg):
- Artifacts: ~1 GB avg (3-day retention) → $0.12/month
- Releases: ~50 GB total → Free (within LFS quota)
- **Total**: ~$0.12/month

**Cost control**:
```yaml
# In repo settings or workflow
retention-days: 1  # Minimize artifact storage

# Or org-wide policy
# Settings → Actions → Artifact and log retention → 1 day
```

---

### For Very High Volume (Advanced)
If you're generating 100+ bundles/day and hitting storage limits:

1. **Use "rolling release" pattern**:
   - Single Release tag: `m2-bundles-latest`
   - Overwrite assets daily with `--clobber`
   - Keep only last N versions

2. **Use external storage** (GCS/S3) for long-term:
   - Workflow uploads to GitHub Release (public URLs)
   - Workflow also archives to GCS (backup/analytics)
   - Clean up old Release assets after 30 days

3. **Use bundle composition**:
   - Store "base bundles" (clojure-core, web-stack)
   - Users compose bundles client-side
   - Reduces total unique bundles

---

## Monitoring & Alerts

### Check Current Usage

**Via Web UI**:
1. Settings → Billing and plans → Plans and usage
2. View "Actions & Packages" storage

**Via API**:
```bash
# Get storage for user/org
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/users/USERNAME/settings/billing/shared-storage

# Response:
# {
#   "days_left_in_billing_cycle": 15,
#   "estimated_paid_storage_for_month": 0,
#   "estimated_storage_for_month": 450  # MB
# }
```

### Set Alerts

**Spending limit** (prevent runaway costs):
1. Settings → Billing and plans → Spending limits
2. Set monthly limit (e.g., $10)
3. Choose action: email alert or disable Actions

**Usage notifications**:
1. Settings → Notifications
2. Enable "Actions and packages" notifications
3. Get email at 75%, 90%, 100% of quota

---

## FAQ

### Q: Do artifacts count against my repo size limit?
**A**: No. Repo size limit is 1 GB recommended (5 GB hard limit), but artifacts are stored separately and don't count toward this.

### Q: Can I download artifacts without `gh` CLI?
**A**: Yes, via REST API with a PAT, or manually via Web UI. `gh` is just the easiest method for automation.

### Q: Do Release assets expire?
**A**: No, they persist until manually deleted.

### Q: What happens if I exceed my Actions storage quota?
**A**: New artifact uploads fail until you either delete old artifacts, upgrade your plan, or increase your spending limit.

### Q: Can I share artifacts across repos?
**A**: Not directly. Artifacts belong to a specific workflow run. Use Releases for cross-repo sharing.

### Q: Do private repo Release assets require auth?
**A**: Yes, for private repos. Only public repos have unauthenticated download URLs.

---

## Summary Table

| Aspect | Artifacts | Release Assets |
|--------|-----------|----------------|
| Max size | 5 GB | 2 GB |
| Retention | 1-400 days | Permanent |
| Public URL | ❌ | ✅ (public repos) |
| Free tier | 500 MB - 50 GB | Unlimited (effectively) |
| Paid cost | $0.24/GB/month | Free (bandwidth soft limits) |
| Best for | Temp build outputs | Permanent distribution |
| Access outside workflow | `gh` CLI, API, Web UI | Direct URL (public), API (private) |
| M2 bundles | ✅ Short-term cache | ✅ Long-term library |

**Recommendation for this project**: Use **Release Assets** for all public bundles, with artifacts only as intermediate build output (1-day retention).

---

## References

- [GitHub Docs: Storing workflow data as artifacts](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
- [GitHub Docs: Billing for GitHub Actions](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)
- [GitHub Community: Are artifacts free for public repos?](https://github.community/)
- [actions/upload-artifact@v4](https://github.com/actions/upload-artifact)
- [actions/download-artifact@v4](https://github.com/actions/download-artifact)

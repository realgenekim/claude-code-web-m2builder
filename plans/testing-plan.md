# M2 Builder Testing Plan: Problematic Dependencies

## Overview

This plan focuses on **testing with real-world "problem dependencies"** - the large, complex dependency sets that are hardest to access in sandboxed environments and most likely to break. If we can handle Google Cloud libraries, AWS SDKs, and Apache Spark, we can handle anything.

## Why These Dependencies Are Hard

### Google Cloud Platform Libraries
**Problem**: Massive transitive dependency trees
- Single library pulls in 50+ transitive deps
- Total .m2 size: 300-500 MB per service
- Frequent version conflicts
- Auth libraries have native dependencies

**Example**: `google-cloud-storage` alone pulls in:
- `google-cloud-core`
- `google-api-client`
- `google-http-client`
- `google-auth-library`
- `grpc-*` (many variants)
- `protobuf-java`
- Plus 40+ more transitive deps

### AWS SDK
**Problem**: Even larger than GCP
- AWS SDK v2 is modular but still huge
- Each service is 20-50 MB
- BOM (Bill of Materials) management required

### Apache Spark
**Problem**: Ecosystem chaos
- Scala version matrix (2.12, 2.13)
- Hadoop version conflicts
- Native library dependencies (compression codecs)
- 500+ MB for a basic Spark project

### Other Known Problematic Libraries
- **Kafka**: Native dependencies, multiple API versions
- **Netty**: Platform-specific native transports
- **Hadoop**: Enormous dependency tree
- **Elasticsearch**: Version-sensitive client libraries

---

## Test Strategy: 3 Tiers

### Tier 1: Baseline (Must Work)
Simple, small bundles to validate basic functionality.

### Tier 2: Real World (Should Work)
Common stacks that users actually need.

### Tier 3: Stress Test (Nice to Have)
Deliberately problematic dependencies to find limits.

---

## Tier 1: Baseline Tests

### Test 1.1: Minimal Clojure
**Bundle**: `clojure-minimal`

**Purpose**: Validate absolute basics work.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "clojure-minimal"
 :version "1.0.0"
 :description "Pure Clojure stdlib only"
 :maintainer "@realgenekim"
 :deps {org.clojure/clojure {:mvn/version "1.11.3"}}}
```

**Expected outcomes**:
- Build time: < 1 minute
- Bundle size: ~10-15 MB
- Zero failures

**Success criteria**: ✅ If this fails, nothing else will work.

---

### Test 1.2: Core + Tools
**Bundle**: `clojure-core`

**Purpose**: Add common Clojure tools.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "clojure-core"
 :version "1.0.0"
 :description "Clojure stdlib + essential tools"
 :maintainer "@realgenekim"
 :deps
 {org.clojure/clojure {:mvn/version "1.11.3"}
  org.clojure/tools.cli {:mvn/version "1.1.230"}
  org.clojure/tools.logging {:mvn/version "1.3.0"}
  org.clojure/data.json {:mvn/version "2.5.0"}
  org.clojure/core.async {:mvn/version "1.6.681"}}}
```

**Expected outcomes**:
- Build time: 1-2 minutes
- Bundle size: ~20-25 MB
- Zero failures

**Success criteria**: ✅ All common Clojure libs downloadable.

---

### Test 1.3: Simple Web Stack
**Bundle**: `web-minimal`

**Purpose**: Small web server (Ring core only).

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "web-minimal"
 :version "1.0.0"
 :description "Ring core + Jetty adapter"
 :maintainer "@realgenekim"
 :deps
 {ring/ring-core {:mvn/version "1.12.2"}
  ring/ring-jetty-adapter {:mvn/version "1.12.2"}}}
```

**Expected outcomes**:
- Build time: 1-2 minutes
- Bundle size: ~8-10 MB
- Zero failures

**Success criteria**: ✅ Basic web deps resolve.

---

## Tier 2: Real World Tests

### Test 2.1: Full Web Stack
**Bundle**: `web-stack`

**Purpose**: Complete web development environment.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "web-stack"
 :version "1.0.0"
 :description "Complete web stack: Ring, Compojure, Reitit, Selmer, JSON"
 :maintainer "@realgenekim"
 :tags ["web" "http" "rest" "json" "routing"]
 :size-estimate-mb 80
 :deps
 {; Core web
  ring/ring-core {:mvn/version "1.12.2"}
  ring/ring-jetty-adapter {:mvn/version "1.12.2"}
  ring/ring-json {:mvn/version "0.5.1"}
  ring/ring-defaults {:mvn/version "0.4.0"}

  ; Routing
  compojure/compojure {:mvn/version "1.7.1"}
  metosin/reitit {:mvn/version "0.7.2"}

  ; JSON
  cheshire/cheshire {:mvn/version "5.12.0"}

  ; Templates
  selmer/selmer {:mvn/version "1.12.61"}

  ; HTTP client
  clj-http/clj-http {:mvn/version "3.13.0"}}}
```

**Expected outcomes**:
- Build time: 2-3 minutes
- Bundle size: 60-80 MB
- Possible transitive conflicts (Ring vs. Reitit deps)

**Success criteria**: ✅ All deps resolve without conflicts.

---

### Test 2.2: Database Stack
**Bundle**: `database-stack`

**Purpose**: JDBC + connection pooling + migrations.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "database-stack"
 :version "1.0.0"
 :description "PostgreSQL JDBC + HikariCP + next.jdbc"
 :maintainer "@realgenekim"
 :tags ["database" "sql" "postgresql"]
 :size-estimate-mb 25
 :deps
 {; JDBC
  com.github.seancorfield/next.jdbc {:mvn/version "1.3.939"}
  org.postgresql/postgresql {:mvn/version "42.7.3"}

  ; Connection pooling
  com.zaxxer/HikariCP {:mvn/version "5.1.0"}

  ; Migrations
  org.flywaydb/flyway-core {:mvn/version "10.18.0"}

  ; SQL helpers
  com.github.seancorfield/honeysql {:mvn/version "2.6.1147"}}}
```

**Expected outcomes**:
- Build time: 1-2 minutes
- Bundle size: 20-30 MB
- PostgreSQL JDBC is reliable

**Success criteria**: ✅ JDBC drivers download correctly.

---

### Test 2.3: Testing Stack
**Bundle**: `testing-stack`

**Purpose**: Test frameworks + mocking + property testing.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "testing-stack"
 :version "1.0.0"
 :description "Kaocha + clojure.test + test.check"
 :maintainer "@realgenekim"
 :tags ["testing" "tdd"]
 :size-estimate-mb 35
 :deps
 {; Test runner
  lambdaisland/kaocha {:mvn/version "1.91.1392"}

  ; Property testing
  org.clojure/test.check {:mvn/version "1.1.1"}

  ; Mocking
  nubank/matcher-combinators {:mvn/version "3.9.1"}}}
```

**Expected outcomes**:
- Build time: 2-3 minutes
- Bundle size: 30-40 MB
- Kaocha has many transitive deps

**Success criteria**: ✅ Test frameworks download.

---

## Tier 3: Stress Tests (Problematic Dependencies)

### Test 3.1: Google Cloud Storage (The Classic Problem)
**Bundle**: `gcs-client`

**Purpose**: Test Google Cloud library hell.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "gcs-client"
 :version "1.0.0"
 :description "Google Cloud Storage Java client"
 :maintainer "@realgenekim"
 :tags ["google-cloud" "gcs" "storage"]
 :size-estimate-mb 450
 :deps
 {com.google.cloud/google-cloud-storage {:mvn/version "2.52.0"}}}
```

**Known issues**:
- 50+ transitive dependencies
- gRPC native libraries (platform-specific)
- Protobuf version conflicts
- Auth libraries

**Expected outcomes**:
- Build time: 4-6 minutes
- Bundle size: 400-500 MB
- **Likely failures**:
  - `grpc-netty-shaded` platform detection
  - Protobuf version conflicts
  - Maven Central rate limiting

**Mitigation strategies**:
1. Add explicit `:exclusions` for conflicting deps
2. Use BOM (Bill of Materials) import
3. Pin specific gRPC versions

**Improved version** (with BOM):
```clojure
{:deps
 {com.google.cloud/libraries-bom {:mvn/version "26.50.0"}
  com.google.cloud/google-cloud-storage {:mvn/version "2.52.0"}}
 :mvn/repos
 {"central" {:url "https://repo1.maven.org/maven2/"}
  "google-maven-central" {:url "https://maven-central.storage-download.googleapis.com/maven2/"}}}
```

**Success criteria**:
- ✅ Downloads complete (even if slow)
- ✅ Bundle < 600 MB (within GitHub 2 GB limit)
- ⚠️ Acceptable: 5-10 minute build time

**Failure modes to document**:
- If build times > 10 min, recommend splitting into parts
- If size > 1 GB, create `gcs-client-minimal` variant

---

### Test 3.2: Google Cloud Full Suite
**Bundle**: `google-cloud-full`

**Purpose**: Stress test with multiple GCP services.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "google-cloud-full"
 :version "1.0.0"
 :description "GCP: Storage, Firestore, PubSub, BigQuery, Secret Manager"
 :maintainer "@realgenekim"
 :tags ["google-cloud" "gcs" "firestore" "pubsub" "bigquery"]
 :size-estimate-mb 800
 :deps
 {; Use BOM to manage versions
  com.google.cloud/libraries-bom {:mvn/version "26.50.0"}

  ; Individual services
  com.google.cloud/google-cloud-storage {:mvn/version "2.52.0"}
  com.google.cloud/google-cloud-firestore {:mvn/version "3.29.3"}
  com.google.cloud/google-cloud-pubsub {:mvn/version "1.134.3"}
  com.google.cloud/google-cloud-bigquery {:mvn/version "2.44.4"}
  com.google.cloud/google-cloud-secretmanager {:mvn/version "2.54.0"}}}
```

**Expected outcomes**:
- Build time: 8-12 minutes ⚠️
- Bundle size: 700-900 MB ⚠️
- **Highly likely failures**:
  - Dependency convergence issues
  - GitHub Actions timeout (6 hour limit)
  - Network timeouts from Maven Central

**Success criteria**:
- ✅ If it completes, we can handle anything
- ⚠️ Acceptable: Build takes 10+ minutes
- ❌ Failure mode: Split into per-service bundles

**Fallback bundles** (if full suite fails):
- `gcs-only` (Storage only)
- `gcp-data` (BigQuery + Storage)
- `gcp-messaging` (PubSub + Storage)

---

### Test 3.3: AWS SDK v2
**Bundle**: `aws-s3`

**Purpose**: Test AWS SDK v2 modular architecture.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "aws-s3"
 :version "1.0.0"
 :description "AWS SDK v2 for S3"
 :maintainer "@realgenekim"
 :tags ["aws" "s3" "storage"]
 :size-estimate-mb 120
 :deps
 {; AWS BOM
  software.amazon.awssdk/bom {:mvn/version "2.29.19"}

  ; S3 client
  software.amazon.awssdk/s3 {:mvn/version "2.29.19"}

  ; Auth
  software.amazon.awssdk/sts {:mvn/version "2.29.19"}}}
```

**Expected outcomes**:
- Build time: 3-5 minutes
- Bundle size: 100-150 MB
- AWS SDK v2 is cleaner than v1, should be easier than GCP

**Success criteria**: ✅ Faster and smaller than GCP equivalent.

---

### Test 3.4: Apache Spark
**Bundle**: `spark-core`

**Purpose**: Test Scala interop + Hadoop deps.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "spark-core"
 :version "1.0.0"
 :description "Apache Spark 3.5 (Scala 2.13)"
 :maintainer "@realgenekim"
 :tags ["spark" "big-data" "hadoop"]
 :size-estimate-mb 600
 :deps
 {; Spark core
  org.apache.spark/spark-core_2.13 {:mvn/version "3.5.3"
                                    :exclusions [org.slf4j/slf4j-log4j12]}

  ; Spark SQL
  org.apache.spark/spark-sql_2.13 {:mvn/version "3.5.3"}

  ; Hadoop client
  org.apache.hadoop/hadoop-client {:mvn/version "3.3.6"}}}
```

**Expected outcomes**:
- Build time: 6-10 minutes
- Bundle size: 500-700 MB
- **Likely failures**:
  - Scala version conflicts (_2.12 vs _2.13)
  - SLF4J binding conflicts
  - Native Hadoop libraries

**Success criteria**:
- ✅ Downloads complete
- ⚠️ May need `:exclusions` for logging conflicts
- ❌ If > 1 GB, create `spark-minimal` (no Hadoop)

---

### Test 3.5: Kitchen Sink
**Bundle**: `kitchen-sink`

**Purpose**: Deliberately combine conflicting libraries.

**deps.edn**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "kitchen-sink"
 :version "1.0.0"
 :description "Stress test: GCP + AWS + Spark + Web"
 :maintainer "@realgenekim"
 :tags ["stress-test"]
 :size-estimate-mb 1500
 :deps
 {; GCP
  com.google.cloud/google-cloud-storage {:mvn/version "2.52.0"}

  ; AWS
  software.amazon.awssdk/s3 {:mvn/version "2.29.19"}

  ; Spark
  org.apache.spark/spark-core_2.13 {:mvn/version "3.5.3"
                                    :exclusions [org.slf4j/slf4j-log4j12]}

  ; Web
  ring/ring-core {:mvn/version "1.12.2"}

  ; Database
  org.postgresql/postgresql {:mvn/version "42.7.3"}}}
```

**Expected outcomes**:
- Build time: 10-15 minutes ⚠️
- Bundle size: 1.2-1.5 GB ⚠️
- **Expected failures**:
  - Netty version conflicts (GCP gRPC vs. AWS)
  - Protobuf conflicts
  - SLF4J conflicts
  - GitHub Release asset 2 GB limit may be approached

**Success criteria**:
- ⚠️ If this works, we've solved the hardest problem
- ❌ Expected to fail initially
- 🎯 Goal: Document conflicts and provide resolution strategies

**Conflict resolution strategies to test**:
1. Explicit `:exclusions`
2. Dependency convergence report
3. Forced versions via `:override-deps`

---

## Test Execution Plan

### Phase 1: Baseline (Week 1, Day 1-2)
**Objective**: Prove basic functionality.

**Tests**: Tier 1 (1.1, 1.2, 1.3)

**Steps**:
1. Create bundle definitions
2. Commit to `bundles/`
3. Push to trigger GitHub Actions
4. Wait for builds
5. Download and verify tarballs

**Success gate**: All 3 Tier 1 tests pass → proceed to Phase 2.

**If failures**:
- Fix workflow bugs
- Adjust timeouts
- Debug EDN parsing

---

### Phase 2: Real World (Week 1, Day 3-4)
**Objective**: Validate common use cases.

**Tests**: Tier 2 (2.1, 2.2, 2.3)

**Steps**:
1. Create bundle definitions
2. Push to repo
3. Monitor build times
4. Verify bundle sizes
5. Test extraction and use

**Success gate**: At least 2/3 Tier 2 tests pass → proceed to Phase 3.

**Expected issues**:
- Transitive dependency conflicts
- Longer build times

**Mitigation**:
- Add `:exclusions` as needed
- Document common conflicts

---

### Phase 3: Stress Tests (Week 1, Day 5 - Week 2)
**Objective**: Find limits and document failure modes.

**Tests**: Tier 3 (3.1, 3.2, 3.3, 3.4, 3.5)

**Order of execution**:
1. **3.1 GCS** - The known hard problem
2. **3.3 AWS** - Easier alternative to GCS
3. **3.4 Spark** - Different class of problem (Scala + Hadoop)
4. **3.2 Google Full** - Multiple GCP services
5. **3.5 Kitchen Sink** - Expected to fail, learn from it

**For each test**:

**Step 1: Initial attempt**
- Create bundle definition
- Push to repo
- Observe GitHub Actions

**Step 2: If build fails**
- Capture error logs
- Identify root cause (dependency conflict, timeout, size limit)
- Document in `docs/known-issues.md`

**Step 3: If build succeeds but bundle > 1 GB**
- Document size
- Consider splitting bundle
- Test download speed

**Step 4: If build times > 10 minutes**
- Document
- Consider if acceptable or needs optimization

**Success criteria**:
- ✅ At least **3.1 (GCS)** and **3.3 (AWS)** pass
- ⚠️ **3.2 (Google Full)** may fail, acceptable
- ⚠️ **3.4 (Spark)** may have conflicts, document
- ❌ **3.5 (Kitchen Sink)** expected to fail, use for learning

---

## Metrics to Collect

For each bundle test, record:

### Build Metrics
```yaml
bundle-id: gcs-client
build-date: 2025-11-15T10:30:00Z
github-actions-run: https://github.com/realgenekim/m2builder/actions/runs/123
status: success | failure
build-time-seconds: 320
artifact-count: 52
error-logs: |
  [if failed, paste relevant errors]
```

### Bundle Metrics
```yaml
bundle-id: gcs-client
tarball-size-mb: 487
uncompressed-size-mb: 1203
compression-ratio: 2.47
dependency-count: 52
download-url: https://github.com/.../m2-gcs-client.tar.gz
```

### Download Metrics
```yaml
bundle-id: gcs-client
download-time-seconds: 45
extraction-time-seconds: 12
verify-command: clojure -Spath
verify-status: success
```

### Create tracking spreadsheet
**File**: `test-results.csv`

```csv
bundle_id,tier,status,build_time_sec,size_mb,deps_count,notes
clojure-minimal,1,pass,45,12,1,baseline
clojure-core,1,pass,78,23,5,all tools ok
web-minimal,1,pass,82,9,2,ring ok
web-stack,2,pass,156,68,12,minor conflicts resolved
database-stack,2,pass,95,24,8,postgres ok
testing-stack,2,pass,187,35,15,kaocha deps heavy
gcs-client,3,pass,324,487,52,slow but works!
google-cloud-full,3,fail,timeout,N/A,N/A,exceeded 10 min limit
aws-s3,3,pass,210,118,28,faster than gcp
spark-core,3,pass,445,612,87,scala 2.13 ok
kitchen-sink,3,fail,conflict,N/A,N/A,netty version conflict
```

---

## Known Issues Documentation

Create **`docs/known-issues.md`** to document problems found:

### Template

```markdown
## Issue: [Description]

**Bundle**: `bundle-id`
**Tier**: 1/2/3
**Severity**: Critical | High | Medium | Low

### Symptom
What goes wrong (build failure, timeout, conflicts).

### Root Cause
Technical explanation.

### Workaround
How to fix (exclusions, version overrides).

### Example
```clojure
; Before (fails)
:deps {com.google.cloud/google-cloud-storage {:mvn/version "2.52.0"}}

; After (works)
:deps {com.google.cloud/google-cloud-storage {:mvn/version "2.52.0"
                                              :exclusions [io.grpc/grpc-netty]}}
```

### Status
Open | Resolved | Won't Fix
```

---

## Success Criteria (Overall)

### Minimum Viable Product (MVP)
- ✅ All Tier 1 tests pass (3/3)
- ✅ At least 2/3 Tier 2 tests pass
- ✅ At least 1/5 Tier 3 tests pass (ideally GCS)

### Production Ready
- ✅ All Tier 1 + Tier 2 tests pass (6/6)
- ✅ At least 3/5 Tier 3 tests pass
- ✅ GCS bundle working (the flagship use case)
- ✅ `docs/known-issues.md` comprehensive

### Stretch Goals
- ✅ 4/5 Tier 3 tests pass
- ✅ Kitchen Sink passes (with documented workarounds)
- ✅ All bundles < 1 GB
- ✅ All build times < 8 minutes

---

## Risk Mitigation

### Risk: GitHub Actions timeout (6 hours)
**Likelihood**: Low (even Spark builds in < 15 min)
**Mitigation**: Split large bundles into parts.

### Risk: GitHub Release asset 2 GB limit
**Likelihood**: Medium (Google Full + Spark could hit this)
**Mitigation**:
- Compress better (zstd -19 instead of -3)
- Split bundles
- Document size limits

### Risk: Maven Central rate limiting
**Likelihood**: Medium (high-volume builds)
**Mitigation**:
- Use Google Maven mirror
- Add retry logic to workflow
- Spread tests over time

### Risk: Dependency conflicts unresolvable
**Likelihood**: High (Kitchen Sink designed to trigger this)
**Mitigation**:
- Document exclusions
- Provide multiple bundle variants
- Accept that some combinations won't work

### Risk: Native dependencies fail
**Likelihood**: Medium (gRPC, Netty)
**Mitigation**:
- Test on GitHub's ubuntu-latest runner
- Document platform-specific issues
- Consider multi-platform bundles (future)

---

## Deliverables

By end of testing phase:

1. **Test Results**:
   - `test-results.csv` with all metrics
   - Pass/fail status for all tests

2. **Working Bundles**:
   - All Tier 1 bundles (3)
   - At least 2 Tier 2 bundles
   - At least 1 Tier 3 bundle (GCS)

3. **Documentation**:
   - `docs/known-issues.md` - Problems and workarounds
   - `docs/bundle-best-practices.md` - Lessons learned
   - Updated `bundles/README.md` with status

4. **Workflow Improvements**:
   - Timeout adjustments
   - Better error reporting
   - Size warnings

5. **Proof of Concept**:
   - Demo video/screenshot: Claude Code Web successfully compiling a GCS project using the `gcs-client` bundle

---

## Next Steps After Testing

### If tests reveal we can't handle large bundles (> 1 GB)
**Solution**: Bundle composition
- Create base bundles (e.g., `gcp-core`, `gcp-grpc`)
- Users combine multiple bundles client-side

### If build times are too long (> 10 min)
**Solution**: Pre-warming
- Cron job to rebuild popular bundles nightly
- Keep cached artifacts warm

### If GitHub limits are hit
**Solution**: Hybrid approach
- Small bundles (< 100 MB): GitHub Release
- Large bundles (> 500 MB): GCS with signed URLs
- Update docs to reflect both paths

---

## Test Execution Checklist

### Pre-flight
- [ ] GitHub Actions workflow finalized
- [ ] Bundle schema validated
- [ ] Test tracking spreadsheet created
- [ ] Notification system (monitor workflow status)

### Tier 1 Execution
- [ ] Create `clojure-minimal.edn`
- [ ] Create `clojure-core.edn`
- [ ] Create `web-minimal.edn`
- [ ] Push all to repo
- [ ] Monitor builds
- [ ] Download and verify
- [ ] Record metrics
- [ ] **Gate**: All pass → proceed

### Tier 2 Execution
- [ ] Create `web-stack.edn`
- [ ] Create `database-stack.edn`
- [ ] Create `testing-stack.edn`
- [ ] Push all to repo
- [ ] Monitor builds
- [ ] Download and verify
- [ ] Record metrics
- [ ] Document any issues
- [ ] **Gate**: 2/3 pass → proceed

### Tier 3 Execution
- [ ] Create `gcs-client.edn` (highest priority)
- [ ] Push and monitor
- [ ] **If GCS succeeds**: 🎉 Major milestone!
- [ ] **If GCS fails**: Debug, iterate, document
- [ ] Create `aws-s3.edn`
- [ ] Create `spark-core.edn`
- [ ] Create `google-cloud-full.edn`
- [ ] Create `kitchen-sink.edn`
- [ ] For each: push, monitor, record
- [ ] Document all failures in `known-issues.md`

### Post-testing
- [ ] Compile test results
- [ ] Write `bundle-best-practices.md`
- [ ] Update main README with test results
- [ ] Create demo (screenshot or video of working GCS bundle)
- [ ] Retrospective: what did we learn?

---

## Appendix: Quick Reference

### Bundle Size Estimates
| Bundle | Estimated Size | Risk Level |
|--------|---------------|------------|
| clojure-minimal | ~15 MB | ✅ Low |
| clojure-core | ~25 MB | ✅ Low |
| web-minimal | ~10 MB | ✅ Low |
| web-stack | ~70 MB | ✅ Low |
| database-stack | ~25 MB | ✅ Low |
| testing-stack | ~35 MB | ✅ Low |
| gcs-client | **~450 MB** | ⚠️ High |
| google-cloud-full | **~800 MB** | ⚠️ Very High |
| aws-s3 | ~120 MB | ⚠️ Medium |
| spark-core | **~600 MB** | ⚠️ Very High |
| kitchen-sink | **~1.5 GB** | ❌ Extreme |

### Build Time Estimates
| Bundle | Est. Build Time | Risk |
|--------|----------------|------|
| Tier 1 | 1-2 min | ✅ Low |
| Tier 2 | 2-4 min | ✅ Low |
| GCS | 4-6 min | ⚠️ Medium |
| AWS | 3-5 min | ✅ Low |
| Spark | 6-10 min | ⚠️ High |
| Google Full | 8-12 min | ⚠️ Very High |
| Kitchen Sink | 10-15 min | ❌ Extreme |

---

**Owner**: @realgenekim
**Timeline**: Week 1-2 of implementation phase
**Priority**: High (this validates the entire system)

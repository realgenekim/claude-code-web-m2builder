# M2 Bundle Creation Process

**Step-by-step documentation of how M2 dependency bundles are created**

---

## Overview

M2 bundles are compressed tarballs containing Maven repository artifacts (JARs, POMs, etc.) for a specific set of Clojure dependencies. They allow sandboxed environments to use dependencies without accessing Maven Central.

---

## Process Steps

### 1. Read Bundle Definition

**Input**: Bundle ID (e.g., `"reddit-scraper-server2"`)

**Action**: Read EDN file from `bundles/{bundle-id}.edn`

**Example**:
```clojure
{:schema-version "1.0.0"
 :bundle-id "reddit-scraper-server2"
 :deps {org.clojure/clojure {:mvn/version "1.11.3"}
        http-kit/http-kit {:mvn/version "2.8.0"}
        ;; ... more dependencies}}
```

**Code**:
```clojure
(defn read-bundle-def [bundle-id]
  (let [bundle-file (io/file "bundles" (str bundle-id ".edn"))]
    (edn/read-string (slurp bundle-file))))
```

---

### 2. Create Temporary M2 Directory

**Purpose**: Isolated Maven local repository for this bundle

**Location**: `/tmp/m2-{bundle-id}-{timestamp}/`

**Example**: `/tmp/m2-reddit-scraper-server2-1763257440607/`

**Code**:
```clojure
(defn create-temp-m2-dir [bundle-id]
  (let [timestamp (System/currentTimeMillis)
        temp-dir (io/file "/tmp" (str "m2-" bundle-id "-" timestamp))]
    (.mkdirs temp-dir)
    (.getAbsolutePath temp-dir)))
```

---

### 3. Create Temporary Project Directory

**Purpose**: Clojure needs a `deps.edn` file in a directory to resolve dependencies

**Location**: `/tmp/clj-project-{timestamp}/`

**Files Created**:
```
/tmp/clj-project-{timestamp}/
└── deps.edn    # Contains {:deps {...}}
```

**Code**:
```clojure
(let [temp-project-dir (str "/tmp/clj-project-" (System/currentTimeMillis))
      deps-edn-content (pr-str {:deps deps-map})]
  (.mkdirs (io/file temp-project-dir))
  (spit (io/file temp-project-dir "deps.edn") deps-edn-content))
```

---

### 4. Download Dependencies

**Command Executed**:
```bash
clojure \
  -Sdeps '{:mvn/local-repo "/tmp/m2-reddit-scraper-server2-1763257440607"}' \
  -Srepro \
  -Sforce \
  -P
```

**Executed From**: Temp project directory (with deps.edn)

**Flags Explained**:
- `-Sdeps '{:mvn/local-repo "..."}'` - Override Maven local repo location
- `-Srepro` - Ignore user/global deps.edn (reproducible)
- `-Sforce` - Force re-resolution of dependencies
- `-P` - Prepare (download deps only, don't run anything)

**What Happens**:
1. Clojure reads `deps.edn` from current directory
2. Resolves all transitive dependencies from Maven Central
3. Downloads JARs and POMs to `/tmp/m2-{bundle-id}-{timestamp}/`
4. Creates Maven repository structure:
   ```
   /tmp/m2-reddit-scraper-server2-1763257440607/
   ├── org/
   │   └── clojure/
   │       └── clojure/
   │           └── 1.11.3/
   │               ├── clojure-1.11.3.jar
   │               ├── clojure-1.11.3.pom
   │               └── _remote.repositories
   ├── http-kit/
   │   └── http-kit/
   │       └── 2.8.0/
   │           ├── http-kit-2.8.0.jar
   │           └── http-kit-2.8.0.pom
   └── ... (127 more JARs)
   ```

**Code**:
```clojure
(sh/sh "clojure"
       "-Sdeps" (str "{:mvn/local-repo \"" m2-dir "\"}")
       "-Srepro"
       "-Sforce"
       "-P"
       :dir temp-project-dir)
```

**Result**: 129 JARs downloaded (~30 MB uncompressed)

---

### 5. Create Tarball

**Command Executed**:
```bash
tar -czf /tmp/m2-reddit-scraper-server2-1763257440607.tar.gz \
    -C /tmp/m2-reddit-scraper-server2-1763257440607 \
    .
```

**Flags Explained**:
- `-c` - Create archive
- `-z` - Compress with gzip
- `-f` - Output file
- `-C` - Change to directory before archiving
- `.` - Archive everything in directory

**Important**: The `-C` flag ensures the tarball **doesn't include** the parent directory path. When extracted, it creates the `.m2/repository/` structure directly.

**Code**:
```clojure
(defn create-tarball [m2-dir bundle-id timestamp]
  (let [tarball-path (str "/tmp/m2-" bundle-id "-" timestamp ".tar.gz")]
    (sh/sh "tar" "-czf" tarball-path
           "-C" m2-dir
           ".")
    {:tarball-path tarball-path
     :size-bytes (.length (io/file tarball-path))
     :size-mb (/ (.length (io/file tarball-path)) 1024.0 1024.0)}))
```

**Result**: `24.4 MB` compressed tarball

---

### 6. Upload to GCS

**Versioned Upload**:
```bash
gsutil cp /tmp/m2-reddit-scraper-server2-1763257440607.tar.gz \
  gs://gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-1763257440607.tar.gz
```

**Latest Upload** (same file, different name):
```bash
gsutil cp /tmp/m2-reddit-scraper-server2-1763257440607.tar.gz \
  gs://gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-latest.tar.gz
```

**Metadata Upload**:
```bash
# Create metadata JSON
{
  "bundle-id": "reddit-scraper-server2",
  "timestamp": 1763257440607,
  "size-mb": 24.4,
  "artifact-count": 129,
  "build-time-seconds": 25.0,
  "versioned-url": "https://storage.googleapis.com/.../reddit-scraper-server2-1763257440607.tar.gz"
}

# Upload metadata
gsutil cp metadata.json \
  gs://.../m2/metadata/reddit-scraper-server2-1763257440607.json
```

**Code**:
```clojure
(defn upload-to-gcs [tarball-path bundle-id timestamp]
  (let [gcs-versioned-path (str gcs-m2-path "/" bundle-id "-" timestamp ".tar.gz")
        gcs-latest-path (str gcs-m2-path "/" bundle-id "-latest.tar.gz")]
    (sh/sh "gsutil" "-q" "cp" tarball-path gcs-versioned-path)
    (sh/sh "gsutil" "-q" "cp" tarball-path gcs-latest-path)
    {:versioned-url (str "https://storage.googleapis.com/..." )
     :latest-url (str "https://storage.googleapis.com/...")}))
```

---

### 7. Cleanup

**Files Deleted**:
- `/tmp/m2-reddit-scraper-server2-1763257440607/` (M2 directory)
- `/tmp/m2-reddit-scraper-server2-1763257440607.tar.gz` (tarball)
- `/tmp/clj-project-{timestamp}/` (temp project)

**Code**:
```clojure
(sh/sh "rm" "-rf" m2-dir)
(.delete (io/file tarball-path))
```

---

## Complete Example Run

### Input
```clojure
(bundle/build-bundle {:bundle-id "reddit-scraper-server2"})
```

### Output
```
════════════════════════════════════════════════════════════
Building M2 Bundle: reddit-scraper-server2
════════════════════════════════════════════════════════════
Downloading dependencies to /tmp/m2-reddit-scraper-server2-1763257440607 ...
  Using deps: (org.clojure/clojure http-kit/http-kit ...)
  ✓ Downloaded 129 JAR files
Creating tarball...
  From: /tmp/m2-reddit-scraper-server2-1763257440607
  To: /tmp/m2-reddit-scraper-server2-1763257440607.tar.gz
  ✓ Created: 24.4 MB
Uploading to GCS...
  Versioned: gs://.../m2/reddit-scraper-server2-1763257440607.tar.gz
  Latest: gs://.../m2/reddit-scraper-server2-latest.tar.gz
  ✓ Uploaded
Cleaning up temporary files...
  ✓ Cleaned up

════════════════════════════════════════════════════════════
✅ Bundle built successfully!
════════════════════════════════════════════════════════════

Bundle Details:
  Size:       24.4 MB
  JARs:       129
  Build time: 25.0 seconds

Download URLs:
  Versioned: https://storage.googleapis.com/.../reddit-scraper-server2-1763257440607.tar.gz
  Latest:    https://storage.googleapis.com/.../reddit-scraper-server2-latest.tar.gz
```

---

## Usage (Download and Extract)

### From GCS to Local
```bash
# Create directory
mkdir -p ~/.m2-cache-reddit-scraper-server2

# Download
curl -L -o ~/.m2-cache-reddit-scraper-server2/bundle.tar.gz \
  https://storage.googleapis.com/gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd/m2/reddit-scraper-server2-latest.tar.gz

# Extract
cd ~/.m2-cache-reddit-scraper-server2
tar -xzf bundle.tar.gz
rm bundle.tar.gz

# Result: 30 MB, 129 JARs
```

### Configure Clojure to Use Bundle
```bash
# Option 1: Environment variable
export CLJ_CONFIG=/tmp/.clj-config
mkdir -p $CLJ_CONFIG
echo '{:mvn/local-repo "/Users/genekim/.m2-cache-reddit-scraper-server2"}' > $CLJ_CONFIG/deps.edn

# Option 2: Per-command
clojure -Sdeps '{:mvn/local-repo "/Users/genekim/.m2-cache-reddit-scraper-server2"}' -M:dev

# Verify
clojure -Spath | grep '.m2-cache-reddit-scraper-server2'
```

---

## Key Insights

### Why This Works

1. **Isolated M2 repo**: Custom `-Sdeps {:mvn/local-repo ...}` creates standalone cache
2. **Complete structure**: Maven repo includes all transitive deps automatically
3. **Reproducible**: Same `deps.edn` → same bundle (hermetic builds)
4. **Portable**: Tarball can be extracted anywhere
5. **No network needed**: Once extracted, Clojure finds everything locally

### Why `-C` Flag in tar

**Without `-C`**:
```
bundle.tar.gz
└── tmp/
    └── m2-reddit-scraper-server2-1763257440607/
        └── org/
            └── clojure/
                └── ...
```

**With `-C`** (correct):
```
bundle.tar.gz
└── org/
    └── clojure/
        └── ...
```

The `-C` flag ensures extraction creates the `.m2/repository/` structure directly at the target location.

---

## Troubleshooting

### "Downloaded 0 JARs"

**Cause**: Not running `clojure -P` from a directory with `deps.edn`

**Solution**: Create temp project directory with deps.edn file first

### "Dependencies still downloading after extraction"

**Cause**: Clojure not configured to use the bundle

**Solution**: Set `:mvn/local-repo` in deps.edn or via `-Sdeps`

### "Bundle missing transitive dependencies"

**Cause**: Incomplete deps.edn in bundle definition

**Solution**: Let Clojure resolve transitives (it does this automatically with `-P`)

---

## See Also

- [Bundle Schema](./bundle-schema.md) - EDN bundle definition format
- [M2 Bundler Operations](./m2-bundler-operations.md) - Running the service
- [Claude Agent Guide](../claude-agent/README.md) - Using bundles from sandboxes

---

**Generated**: 2025-11-16
**Bundle Example**: reddit-scraper-server2 (24.4 MB, 129 JARs, 25s build time)

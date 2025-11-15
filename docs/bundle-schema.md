# Bundle Schema Specification

## Overview

This document defines the EDN format for M2 bundle definitions. Each bundle represents a curated set of Maven/Clojure dependencies that will be prewarmed into an .m2 cache and distributed as a tarball.

## Schema Version

**Current version**: `1.0.0`

Future schema changes will be versioned to maintain backward compatibility.

---

## Bundle Definition Format

### Complete Example

**File**: `bundles/web-stack.edn`

```clojure
{:schema-version "1.0.0"                 ; Required: Schema version
 :bundle-id "web-stack"                  ; Required: Unique identifier
 :version "1.2.0"                        ; Required: Bundle version (semver)
 :description "Ring + HTTP-Kit + Cheshire + Compojure web stack"  ; Required
 :maintainer "@realgenekim"              ; Required: GitHub handle
 :tags ["web" "http" "rest" "json"]      ; Optional: Searchability
 :upstream-url "https://example.com/docs" ; Optional: Reference docs
 :license "EPL-1.0"                      ; Optional: Overall license
 :size-estimate-mb 45                    ; Optional: Compressed size hint
 :deps                                   ; Required: Clojure deps map
 {ring/ring-core {:mvn/version "1.12.2"}
  ring/ring-jetty-adapter {:mvn/version "1.12.2"}
  http-kit/http-kit {:mvn/version "2.8.0"}
  cheshire/cheshire {:mvn/version "5.12.0"}
  compojure/compojure {:mvn/version "1.7.1"}}
 :aliases                                ; Optional: Predefined aliases
 {:dev {:extra-deps {ring/ring-devel {:mvn/version "1.12.2"}}}}}
```

---

## Field Reference

### Required Fields

#### `:bundle-id`
**Type**: String (kebab-case)

**Description**: Unique identifier for this bundle. Used in filenames, URLs, and references.

**Constraints**:
- Must be unique across all bundles in the repository
- Must match regex: `^[a-z0-9]+(-[a-z0-9]+)*$`
- Length: 3-64 characters
- Recommended: Use semantic names (e.g., `web-stack`, `data-science`, `gcs-client`)

**Examples**:
- ✅ `clojure-core`
- ✅ `web-stack`
- ✅ `google-cloud-storage`
- ❌ `WebStack` (no uppercase)
- ❌ `web_stack` (use hyphens, not underscores)
- ❌ `ws` (too short, not semantic)

---

#### `:schema-version`
**Type**: String (semver)

**Description**: Version of this schema specification. Currently `"1.0.0"`.

**Purpose**: Future-proofing for schema evolution. Validation workflows can reject bundles using unsupported schema versions.

**Current value**: `"1.0.0"`

---

#### `:version`
**Type**: String (semver)

**Description**: Version of this bundle. Increment when dependencies change.

**Constraints**:
- Must be valid semver: `MAJOR.MINOR.PATCH`
- Use semantic versioning principles:
  - **MAJOR**: Breaking changes (remove deps, major version bumps)
  - **MINOR**: Add deps, minor version bumps
  - **PATCH**: Patch-level dependency updates

**Examples**:
- Initial release: `1.0.0`
- Add new dep: `1.1.0`
- Patch update: `1.0.1`
- Remove dep: `2.0.0`

---

#### `:description`
**Type**: String

**Description**: Human-readable summary of what this bundle provides.

**Constraints**:
- Length: 10-200 characters
- Should answer: "What dependencies does this bundle include?"
- Use sentence case
- No markdown formatting

**Examples**:
- ✅ `"Ring + HTTP-Kit + Cheshire web stack"`
- ✅ `"Google Cloud Storage Java client and auth libraries"`
- ✅ `"Core Clojure 1.11.3 + essential tools"`
- ❌ `"web stuff"` (too vague)
- ❌ `"This bundle contains Ring..."` (too verbose)

---

#### `:maintainer`
**Type**: String (GitHub handle)

**Description**: Primary maintainer responsible for this bundle.

**Format**: `@username` (GitHub handle with `@` prefix)

**Purpose**:
- Contact point for issues
- Notified for PRs updating this bundle
- Displayed in bundle registry

**Examples**:
- ✅ `"@realgenekim"`
- ✅ `"@octocat"`
- ❌ `"Gene Kim"` (use GitHub handle)
- ❌ `"realgenekim"` (missing `@`)

**Note**: Multiple maintainers can be supported via `:maintainers` (plural) field in future schema versions.

---

#### `:deps`
**Type**: Map (Clojure tools.deps format)

**Description**: The actual dependency map, equivalent to the `:deps` key in a `deps.edn` file.

**Format**:
```clojure
:deps {lib/name {:mvn/version "X.Y.Z"}
       another/lib {:mvn/version "A.B.C"}}
```

**Constraints**:
- Must be valid tools.deps syntax
- Only `:mvn/version` dependencies supported (no Git deps, local deps)
- All versions must be explicit (no ranges, no "LATEST", no "RELEASE")
- Recommended: Use latest stable versions unless specific version needed

**Validation**:
- Parse as EDN
- Ensure all deps have `:mvn/version` key
- Warn if very old versions detected (heuristic: > 2 years old)

**Example**:
```clojure
:deps
{org.clojure/clojure {:mvn/version "1.11.3"}
 ring/ring-core {:mvn/version "1.12.2"}
 cheshire/cheshire {:mvn/version "5.12.0"}}
```

**Antipatterns**:
```clojure
; ❌ Git deps (not supported yet)
:deps {my/lib {:git/url "..." :git/sha "..."}}

; ❌ Version ranges (not deterministic)
:deps {my/lib {:mvn/version "[1.0.0,2.0.0)"}}

; ❌ Local deps (not portable)
:deps {my/lib {:local/root "../my-lib"}}
```

---

### Optional Fields

#### `:tags`
**Type**: Vector of strings

**Description**: Keywords for discoverability and categorization.

**Constraints**:
- 1-10 tags recommended
- Each tag: lowercase, alphanumeric + hyphens
- Use established tags when possible (see Tag Registry below)

**Examples**:
```clojure
:tags ["web" "http" "rest" "json"]
:tags ["google-cloud" "storage" "gcs"]
:tags ["data" "csv" "excel" "analysis"]
```

**Tag Registry** (community conventions):
- `web` - Web servers, routing, middleware
- `http` - HTTP clients/servers
- `rest` - REST APIs
- `json` - JSON parsing/generation
- `xml` - XML processing
- `database` - Database drivers/clients
- `sql` - SQL databases
- `nosql` - NoSQL databases
- `google-cloud` - Google Cloud Platform
- `aws` - Amazon Web Services
- `azure` - Microsoft Azure
- `data` - Data processing
- `ml` - Machine learning
- `testing` - Test frameworks
- `dev` - Development tools
- `core` - Core libraries
- `minimal` - Minimal dependency set

---

#### `:upstream-url`
**Type**: String (URL)

**Description**: Link to official documentation or homepage for the primary library in this bundle.

**Examples**:
```clojure
:upstream-url "https://github.com/ring-clojure/ring"
:upstream-url "https://cloud.google.com/storage/docs"
```

---

#### `:license`
**Type**: String (SPDX identifier)

**Description**: Overall license for this bundle (if all deps share same license).

**Format**: Use [SPDX identifiers](https://spdx.org/licenses/)

**Common licenses**:
- `EPL-1.0` (Eclipse Public License, common for Clojure libs)
- `Apache-2.0`
- `MIT`
- `BSD-3-Clause`

**Note**: If deps have mixed licenses, omit this field and document in `:description` or README.

---

#### `:size-estimate-mb`
**Type**: Integer

**Description**: Estimated compressed tarball size in megabytes.

**Purpose**: Help users estimate download times and storage needs.

**How to calculate**:
```bash
# After building locally
du -m /tmp/m2-bundle.tar.gz | cut -f1
```

**Examples**:
```clojure
:size-estimate-mb 15   ; Small bundle
:size-estimate-mb 120  ; Large bundle (Google Cloud SDK)
```

---

#### `:aliases`
**Type**: Map (Clojure tools.deps aliases)

**Description**: Predefined aliases that consumers can use (e.g., for dev dependencies, test runners).

**Format**: Same as `:aliases` in `deps.edn`

**Example**:
```clojure
:aliases
{:dev {:extra-deps {ring/ring-devel {:mvn/version "1.12.2"}}}
 :test {:extra-paths ["test"]
        :extra-deps {lambdaisland/kaocha {:mvn/version "1.91.1392"}}}}
```

**Note**: These aliases are metadata only (not used during .m2 warming). Future tooling could support pre-warming aliases.

---

## Validation Rules

### Automated Validation (in CI)

**File**: `.github/workflows/validate-bundle.yml`

**Checks**:

1. **Syntax**:
   - Valid EDN
   - No duplicate keys

2. **Required fields**:
   - All required fields present
   - No empty strings

3. **Field format**:
   - `:bundle-id` matches regex
   - `:version` is valid semver
   - `:maintainer` starts with `@`
   - `:deps` uses only `:mvn/version`

4. **Uniqueness**:
   - `:bundle-id` not already used

5. **Size estimate**:
   - Warn if `:size-estimate-mb` > 500
   - Reject if estimated > 1500 (approaching GitHub 2 GB limit)

6. **Dependency resolution**:
   - Test build locally (download deps)
   - Ensure no 404s from Maven Central

**Example validation script** (pseudocode):
```bash
#!/usr/bin/env bash
# validate-bundle.sh

BUNDLE_FILE=$1

# Check syntax
clojure -M:validate-edn "$BUNDLE_FILE" || exit 1

# Check required fields
required_fields=("bundle-id" "version" "description" "maintainer" "deps")
for field in "${required_fields[@]}"; do
  grep -q ":$field" "$BUNDLE_FILE" || {
    echo "Missing required field: $field"
    exit 1
  }
done

# Check bundle ID format
BUNDLE_ID=$(grep ':bundle-id' "$BUNDLE_FILE" | cut -d'"' -f2)
echo "$BUNDLE_ID" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || {
  echo "Invalid bundle-id format"
  exit 1
}

# Check uniqueness
if [ -f "bundles/$BUNDLE_ID.edn" ] && [ "$BUNDLE_FILE" != "bundles/$BUNDLE_ID.edn" ]; then
  echo "Bundle ID already exists"
  exit 1
fi

# Test build
./scripts/test-bundle-local.sh "$BUNDLE_FILE"
```

---

## Naming Conventions

### Bundle IDs

**Pattern**: `{primary-lib}-{qualifier}`

**Examples**:
- `clojure-core` (Clojure stdlib)
- `ring-full` (Ring with all adapters)
- `ring-minimal` (Ring core only)
- `http-kit-server` (HTTP-Kit as server)
- `google-cloud-storage` (GCS client)
- `aws-s3` (AWS S3 client)
- `data-science` (Tablecloth + tech.ml)

**Guidelines**:
- Use the primary library name as prefix
- Add qualifiers for variants (`-minimal`, `-full`, `-client`, `-server`)
- Use domain for stacks (`web-stack`, `data-stack`)

---

### File Names

**Pattern**: `bundles/{bundle-id}.edn`

**Examples**:
- `bundles/clojure-core.edn`
- `bundles/web-stack.edn`
- `bundles/google-cloud-storage.edn`

**Requirements**:
- File name must match `:bundle-id` field
- Validation workflow enforces this

---

## Migration and Versioning

### Schema Evolution

When this schema needs to evolve:

1. Increment `:schema-version`
2. Update this document
3. Update validation workflows
4. Maintain backward compatibility for N-1 versions (grace period)

**Example future addition**:
```clojure
{:schema-version "1.1.0"  ; New version
 :bundle-id "..."
 :maintainers ["@user1" "@user2"]  ; New field: multiple maintainers
 ...}
```

### Bundle Versioning Best Practices

**When to increment**:

- **Patch** (`1.0.0` → `1.0.1`):
  - Patch-level dependency updates
  - Fix typos in description
  - No functional changes

- **Minor** (`1.0.0` → `1.1.0`):
  - Add new dependencies
  - Minor version bumps of existing deps
  - Add new aliases

- **Major** (`1.0.0` → `2.0.0`):
  - Remove dependencies
  - Major version bumps (e.g., Ring 1.x → 2.x)
  - Breaking changes to aliases

**Version history tracking**:
- Git commits serve as version history
- Each bundle update should be a separate commit
- Commit message format: `Update {bundle-id} to v{version}: {reason}`

**Example**:
```bash
git commit -m "Update web-stack to v1.1.0: Add Hiccup for HTML templating"
```

---

## Example Bundles

### Minimal Example

**File**: `bundles/clojure-minimal.edn`

```clojure
{:schema-version "1.0.0"
 :bundle-id "clojure-minimal"
 :version "1.0.0"
 :description "Pure Clojure 1.11.3 stdlib only"
 :maintainer "@realgenekim"
 :deps {org.clojure/clojure {:mvn/version "1.11.3"}}}
```

---

### Complex Example

**File**: `bundles/full-stack-web.edn`

```clojure
{:schema-version "1.0.0"
 :bundle-id "full-stack-web"
 :version "1.0.0"
 :description "Complete web stack: Ring, Compojure, Reitit, Selmer, JDBC, HikariCP"
 :maintainer "@realgenekim"
 :tags ["web" "http" "rest" "sql" "routing" "templates"]
 :upstream-url "https://github.com/ring-clojure/ring"
 :license "EPL-1.0"
 :size-estimate-mb 80
 :deps
 {; Core web
  ring/ring-core {:mvn/version "1.12.2"}
  ring/ring-jetty-adapter {:mvn/version "1.12.2"}
  ring/ring-json {:mvn/version "0.5.1"}
  compojure/compojure {:mvn/version "1.7.1"}
  metosin/reitit {:mvn/version "0.7.2"}

  ; Templates
  selmer/selmer {:mvn/version "1.12.61"}

  ; JSON
  cheshire/cheshire {:mvn/version "5.12.0"}

  ; Database
  org.clojure/java.jdbc {:mvn/version "0.7.12"}
  com.zaxxer/HikariCP {:mvn/version "5.1.0"}
  org.postgresql/postgresql {:mvn/version "42.7.3"}}

 :aliases
 {:dev {:extra-deps {ring/ring-devel {:mvn/version "1.12.2"}
                     ring/ring-mock {:mvn/version "0.4.0"}}}
  :test {:extra-deps {lambdaisland/kaocha {:mvn/version "1.91.1392"}}}}}
```

---

### Domain-Specific Example

**File**: `bundles/google-cloud-full.edn`

```clojure
{:schema-version "1.0.0"
 :bundle-id "google-cloud-full"
 :version "1.0.0"
 :description "Google Cloud Platform: Storage, Firestore, PubSub, BigQuery"
 :maintainer "@realgenekim"
 :tags ["google-cloud" "gcs" "firestore" "pubsub" "bigquery"]
 :upstream-url "https://cloud.google.com/java/docs/reference"
 :license "Apache-2.0"
 :size-estimate-mb 450
 :deps
 {com.google.cloud/google-cloud-storage {:mvn/version "2.52.0"}
  com.google.cloud/google-cloud-firestore {:mvn/version "3.29.3"}
  com.google.cloud/google-cloud-pubsub {:mvn/version "1.134.3"}
  com.google.cloud/google-cloud-bigquery {:mvn/version "2.44.4"}}}
```

---

## FAQ

### Q: Can I use Git dependencies?
**A**: Not in v1.0.0 of this schema. Only `:mvn/version` deps are supported. Future versions may add Git dep support.

### Q: Can I specify exclusions?
**A**: Yes, use standard tools.deps syntax:
```clojure
:deps {my/lib {:mvn/version "1.0.0"
               :exclusions [unwanted/transitive-dep]}}
```

### Q: Can I have multiple versions of the same bundle?
**A**: Not directly. Increment `:version` in the same file. For major variants, create separate bundle IDs (e.g., `ring-1` vs `ring-2`).

### Q: How do I test my bundle before submitting a PR?
**A**: Use the local test script:
```bash
./scripts/test-bundle-local.sh bundles/my-bundle.edn
```

### Q: Can I compose multiple bundles?
**A**: Not in the bundle definition itself, but consumers can compose bundles client-side by merging manifests. Future tooling may support `:extends` field.

### Q: What if a dependency is no longer available on Maven Central?
**A**: The validation workflow will fail. Update the bundle to use an available alternative or pin to a known-good version in a different repository.

---

## References

- [Clojure tools.deps Reference](https://clojure.org/reference/deps_and_cli)
- [Semantic Versioning](https://semver.org/)
- [SPDX License List](https://spdx.org/licenses/)
- [EDN Specification](https://github.com/edn-format/edn)

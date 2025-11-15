# M2 Bundles

Community-maintained Maven/Clojure dependency bundles.

## Available Bundles

| Bundle ID | Description | Size (Compressed) | Status |
|-----------|-------------|-------------------|--------|
| `clojure-minimal` | Pure Clojure stdlib | 5 MB | ✅ Tested |
| `web-stack` | Ring + Compojure + Reitit + Cheshire | 17 MB | ✅ Tested |
| `gcs-client` | Google Cloud Storage Java client | 47 MB | ✅ Tested |

See [../TEST-RESULTS.md](../TEST-RESULTS.md) for detailed test results.

## Usage

### Download and Use a Bundle

```bash
# Download
curl -L -O https://github.com/realgenekim/m2builder/releases/download/m2-bundles/m2-gcs-client.tar.gz

# Extract
mkdir -p ~/.m2-cache
tar xzf m2-gcs-client.tar.gz -C ~/.m2-cache/

# Use with Clojure
clojure -Sdeps '{:mvn/local-repo "~/.m2-cache/m2-gcs-client"}' -M:your-alias
```

## Contributing

To add a new bundle:

1. Create a bundle definition file in this directory (e.g., `my-bundle.edn`)
2. Follow the schema in [../docs/bundle-schema.md](../docs/bundle-schema.md)
3. Test locally: `../scripts/test-bundle-local.sh bundles/my-bundle.edn`
4. Commit and push - GitHub Actions will build and publish automatically

## Bundle Definition Format

See [../docs/bundle-schema.md](../docs/bundle-schema.md) for the complete specification.

Example:

```clojure
{:schema-version "1.0.0"
 :bundle-id "my-bundle"
 :version "1.0.0"
 :description "Short description"
 :maintainer "@your-github-handle"
 :tags ["tag1" "tag2"]
 :size-estimate-mb 50
 :deps
 {org.clojure/clojure {:mvn/version "1.11.3"}
  some/library {:mvn/version "1.2.3"}}}
```

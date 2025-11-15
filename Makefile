# M2 Builder Makefile

.PHONY: help list-deps build-test bundle bundle-all test-tier1 test-tier2 test-tier3 setup clean-bundles

# Output directory for built bundles
OUTPUT_DIR ?= output

# Default target
help:
	@echo "M2 Builder - Available targets:"
	@echo ""
	@echo "  make list-deps          - List all dependency bundles defined"
	@echo "  make bundle BUNDLE=name - Build a specific bundle (e.g., make bundle BUNDLE=web-stack)"
	@echo "  make bundle-all         - Build all bundles"
	@echo "  make build-test         - Build a test bundle locally (legacy, use 'bundle' instead)"
	@echo "  make test-tier1         - Test Tier 1 bundles (baseline)"
	@echo "  make test-tier2         - Test Tier 2 bundles (real world)"
	@echo "  make test-tier3         - Test Tier 3 bundles (stress tests)"
	@echo "  make setup              - Set up bundle directories"
	@echo "  make clean-bundles      - Clean built bundle artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make bundle BUNDLE=web-stack          - Build web-stack bundle"
	@echo "  make bundle BUNDLE=clojure-minimal    - Build clojure-minimal bundle"
	@echo "  make bundle-all                       - Build all bundles in bundles/"
	@echo ""

# List all bundle definitions
list-deps:
	@echo "=== M2 Bundle Definitions ==="
	@echo ""
	@if [ -d bundles ] && [ -n "$$(ls -A bundles/*.edn 2>/dev/null)" ]; then \
		echo "Tier 1: Baseline Tests"; \
		echo "----------------------"; \
		for bundle in bundles/clojure-minimal.edn bundles/clojure-core.edn bundles/web-minimal.edn; do \
			if [ -f "$$bundle" ]; then \
				ID=$$(basename $$bundle .edn); \
				DESC=$$(grep ':description' $$bundle | cut -d'"' -f2 || echo "No description"); \
				SIZE=$$(grep ':size-estimate-mb' $$bundle | grep -o '[0-9]\+' || echo "?"); \
				echo "  ✓ $$ID ($$SIZE MB) - $$DESC"; \
			fi \
		done; \
		echo ""; \
		echo "Tier 2: Real World"; \
		echo "------------------"; \
		for bundle in bundles/web-stack.edn bundles/database-stack.edn bundles/testing-stack.edn; do \
			if [ -f "$$bundle" ]; then \
				ID=$$(basename $$bundle .edn); \
				DESC=$$(grep ':description' $$bundle | cut -d'"' -f2 || echo "No description"); \
				SIZE=$$(grep ':size-estimate-mb' $$bundle | grep -o '[0-9]\+' || echo "?"); \
				echo "  ✓ $$ID ($$SIZE MB) - $$DESC"; \
			fi \
		done; \
		echo ""; \
		echo "Tier 3: Stress Tests"; \
		echo "--------------------"; \
		for bundle in bundles/gcs-client.edn bundles/google-cloud-full.edn bundles/aws-s3.edn bundles/spark-core.edn bundles/kitchen-sink.edn; do \
			if [ -f "$$bundle" ]; then \
				ID=$$(basename $$bundle .edn); \
				DESC=$$(grep ':description' $$bundle | cut -d'"' -f2 || echo "No description"); \
				SIZE=$$(grep ':size-estimate-mb' $$bundle | grep -o '[0-9]\+' || echo "?"); \
				echo "  ✓ $$ID ($$SIZE MB) - $$DESC"; \
			fi \
		done; \
		echo ""; \
		echo "All bundles:"; \
		echo "------------"; \
		for bundle in bundles/*.edn; do \
			[ -f "$$bundle" ] || continue; \
			ID=$$(basename $$bundle .edn); \
			echo "  - $$ID"; \
		done; \
	else \
		echo "No bundles found in bundles/ directory."; \
		echo "Run 'make setup' to create bundle structure."; \
	fi
	@echo ""

# Set up bundle directories
setup:
	@echo "Setting up M2 builder structure..."
	mkdir -p bundles
	mkdir -p deps-requests
	mkdir -p deps-responses
	mkdir -p .github/workflows
	mkdir -p scripts
	mkdir -p examples
	touch deps-requests/.gitkeep
	touch deps-responses/.gitkeep
	@echo "✓ Directory structure created"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Create bundle definitions in bundles/"
	@echo "  2. See plans/testing-plan.md for test bundles"
	@echo "  3. Run 'make list-deps' to see defined bundles"

# Build a bundle locally for testing (legacy - use 'bundle' target instead)
build-test:
	@if [ -z "$(BUNDLE)" ]; then \
		echo "Usage: make build-test BUNDLE=bundle-name"; \
		echo "Example: make build-test BUNDLE=clojure-minimal"; \
		exit 1; \
	fi
	@if [ ! -f "bundles/$(BUNDLE).edn" ]; then \
		echo "Error: bundles/$(BUNDLE).edn not found"; \
		exit 1; \
	fi
	@echo "Building bundle: $(BUNDLE)"
	@echo "Reading from: bundles/$(BUNDLE).edn"
	@./scripts/test-bundle-local.sh bundles/$(BUNDLE).edn || echo "Note: test-bundle-local.sh not yet implemented"

# Build a specific bundle (mirrors GitHub Actions workflow)
bundle:
	@if [ -z "$(BUNDLE)" ]; then \
		echo "Error: BUNDLE parameter required"; \
		echo "Usage: make bundle BUNDLE=bundle-name"; \
		echo ""; \
		echo "Examples:"; \
		echo "  make bundle BUNDLE=web-stack"; \
		echo "  make bundle BUNDLE=clojure-minimal"; \
		echo ""; \
		echo "Available bundles:"; \
		ls bundles/*.edn 2>/dev/null | xargs -n1 basename | sed 's/\.edn$$//' | sed 's/^/  - /' || echo "  (none found)"; \
		exit 1; \
	fi
	@if [ ! -f "bundles/$(BUNDLE).edn" ]; then \
		echo "Error: bundles/$(BUNDLE).edn not found"; \
		echo ""; \
		echo "Available bundles:"; \
		ls bundles/*.edn 2>/dev/null | xargs -n1 basename | sed 's/\.edn$$//' | sed 's/^/  - /' || echo "  (none found)"; \
		exit 1; \
	fi
	@echo "=== Building Bundle: $(BUNDLE) ==="
	@echo ""
	@# Check for Clojure CLI
	@if ! command -v clojure &> /dev/null; then \
		echo "Error: clojure CLI not found"; \
		echo "Install from: https://clojure.org/guides/install_clojure"; \
		exit 1; \
	fi
	@# Extract metadata
	@DESCRIPTION=$$(grep ':description' bundles/$(BUNDLE).edn | sed 's/.*:description "\([^"]*\)".*/\1/' || echo "No description"); \
	SIZE_EST=$$(grep ':size-estimate-mb' bundles/$(BUNDLE).edn | grep -o '[0-9]\+' || echo "unknown"); \
	echo "Description: $$DESCRIPTION"; \
	echo "Estimated size: $${SIZE_EST} MB"; \
	echo ""
	@# Create output directory
	@mkdir -p $(OUTPUT_DIR)
	@# Create temp M2 directory
	@TMP_M2="/tmp/m2-$(BUNDLE)"; \
	echo "Cleaning previous cache: $$TMP_M2"; \
	rm -rf "$$TMP_M2"; \
	mkdir -p "$$TMP_M2"; \
	echo ""
	@# Create temp directory with bundle file as deps.edn
	@echo "Downloading dependencies..."; \
	echo "This may take several minutes for large bundles..."; \
	echo ""; \
	TMP_M2="/tmp/m2-$(BUNDLE)"; \
	TEMP_DIR="/tmp/bundle-build-$$$$"; \
	mkdir -p "$$TEMP_DIR"; \
	cp bundles/$(BUNDLE).edn "$$TEMP_DIR/deps.edn"; \
	START_TIME=$$(date +%s); \
	cd "$$TEMP_DIR" && clojure -Srepro -Sforce -Sdeps "{:mvn/local-repo \"$$TMP_M2\"}" -P; \
	BUILD_STATUS=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	rm -rf "$$TEMP_DIR"; \
	if [ $$BUILD_STATUS -ne 0 ]; then \
		echo ""; \
		echo "=== Build Failed ==="; \
		rm -rf "$$TMP_M2"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "Dependencies downloaded in $${DURATION}s"; \
	echo ""
	@# Collect statistics and create tarball
	@TMP_M2="/tmp/m2-$(BUNDLE)"; \
	TARBALL="$(OUTPUT_DIR)/m2-$(BUNDLE).tar.gz"; \
	echo "Creating tarball: $$TARBALL"; \
	tar czf "$$TARBALL" -C /tmp "m2-$(BUNDLE)"; \
	SIZE_UNCOMPRESSED=$$(du -sm "$$TMP_M2" | cut -f1); \
	SIZE_COMPRESSED=$$(du -m "$$TARBALL" | cut -f1); \
	ARTIFACT_COUNT=$$(find "$$TMP_M2" -name "*.jar" | wc -l | tr -d ' '); \
	COMPRESSION_RATIO=$$(echo "scale=1; $$SIZE_UNCOMPRESSED / $$SIZE_COMPRESSED" | bc 2>/dev/null || echo "N/A"); \
	echo ""; \
	echo "=== ✅ Bundle Built Successfully ==="; \
	echo ""; \
	echo "Bundle: $(BUNDLE)"; \
	echo "Statistics:"; \
	echo "  - Uncompressed: $${SIZE_UNCOMPRESSED} MB"; \
	echo "  - Compressed: $${SIZE_COMPRESSED} MB"; \
	echo "  - Compression ratio: $${COMPRESSION_RATIO}x"; \
	echo "  - JAR files: $${ARTIFACT_COUNT}"; \
	echo ""; \
	echo "Output: $$TARBALL"; \
	echo ""; \
	echo "To use this bundle:"; \
	echo "  1. Extract: tar xzf $$TARBALL -C ~/.m2-cache/"; \
	echo "  2. Use with Clojure: clojure -Sdeps '{:mvn/local-repo \"$$HOME/.m2-cache/m2-$(BUNDLE)\"}' ..."; \
	echo ""; \
	rm -rf "$$TMP_M2"

# Build all bundles
bundle-all:
	@echo "=== Building All Bundles ==="
	@echo ""
	@if [ ! -d bundles ] || [ -z "$$(ls -A bundles/*.edn 2>/dev/null)" ]; then \
		echo "No bundles found in bundles/ directory"; \
		exit 1; \
	fi
	@mkdir -p $(OUTPUT_DIR)
	@TOTAL=0; \
	SUCCESS=0; \
	FAILED=0; \
	for bundle_file in bundles/*.edn; do \
		[ -f "$$bundle_file" ] || continue; \
		BUNDLE_ID=$$(basename "$$bundle_file" .edn); \
		TOTAL=$$((TOTAL + 1)); \
		echo ""; \
		echo "[$${TOTAL}] Building $$BUNDLE_ID..."; \
		echo "----------------------------------------"; \
		if $(MAKE) bundle BUNDLE=$$BUNDLE_ID OUTPUT_DIR=$(OUTPUT_DIR); then \
			SUCCESS=$$((SUCCESS + 1)); \
		else \
			FAILED=$$((FAILED + 1)); \
			echo "❌ Failed to build $$BUNDLE_ID"; \
		fi; \
	done; \
	echo ""; \
	echo "=== Build Summary ==="; \
	echo "Total: $$TOTAL"; \
	echo "Success: $$SUCCESS"; \
	echo "Failed: $$FAILED"; \
	echo ""; \
	if [ $$FAILED -gt 0 ]; then \
		exit 1; \
	fi

# Clean built bundle artifacts
clean-bundles:
	@echo "Cleaning bundle artifacts..."
	@rm -rf $(OUTPUT_DIR)
	@rm -rf /tmp/m2-*
	@rm -rf /tmp/bundle-build-*
	@echo "✓ Cleaned"

# Test targets (to be implemented with actual bundle files)
test-tier1:
	@echo "Testing Tier 1 bundles (baseline)..."
	@echo "Not yet implemented - bundles need to be created first"

test-tier2:
	@echo "Testing Tier 2 bundles (real world)..."
	@echo "Not yet implemented - bundles need to be created first"

test-tier3:
	@echo "Testing Tier 3 bundles (stress tests)..."
	@echo "Not yet implemented - bundles need to be created first"

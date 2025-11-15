# M2 Builder Makefile

.PHONY: help list-deps build-test test-tier1 test-tier2 test-tier3 setup

# Default target
help:
	@echo "M2 Builder - Available targets:"
	@echo ""
	@echo "  make list-deps          - List all dependency bundles defined"
	@echo "  make build-test         - Build a test bundle locally"
	@echo "  make test-tier1         - Test Tier 1 bundles (baseline)"
	@echo "  make test-tier2         - Test Tier 2 bundles (real world)"
	@echo "  make test-tier3         - Test Tier 3 bundles (stress tests)"
	@echo "  make setup              - Set up bundle directories"
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

# Build a bundle locally for testing
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

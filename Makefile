# Default target when running 'make' without arguments
.DEFAULT_GOAL := help

# Add ~/bin to PATH for Clojure CLI tools
export PATH := $(HOME)/bin:$(PATH)

# Start nREPL server (auto-assigns port, writes to .nrepl-port)
nrepl:
	clojure -M:nrepl

# ========================================
# MCP Server Configuration
# ========================================

# Configure MCP server in Claude Code (dynamically uses current directory)
mcp-configure:
	@echo "🔧 Configuring MCP server in Claude Code..."
	@echo ""
	@echo "Adding Clojure MCP (project-specific tools)..."
	claude mcp add clojure-mcp -- /bin/sh -c 'PORT=$$(cat $(shell pwd)/.nrepl-port); cd $(shell pwd) && clojure -X:mcp:dev:test :port $$PORT'
	@echo ""
	@echo "✅ MCP server configured!"

# Remove MCP server
mcp-remove:
	@echo "🗑️  Removing MCP server..."
	-claude mcp remove clojure-mcp
	@echo "✅ MCP server removed!"

# Run Clojure MCP server locally (for testing)
mcp-run:
	@echo "🚀 Starting Clojure MCP server..."
	@echo "   Reading port from: $(shell pwd)/.nrepl-port"
	PORT=$$(cat $(shell pwd)/.nrepl-port); cd $(shell pwd) && clojure -X:mcp:dev:test :port $$PORT

# ========================================
# Testing
# ========================================

# Run tests with kaocha - watch mode
runtests:
	@echo "Running tests with watcher..."
	bin/kaocha --watch --reporter kaocha.report.progress/report

# Run tests once with fail-fast
runtests-once:
	@echo "Running tests with fail-fast..."
	bin/kaocha --fail-fast

# ========================================
# Development
# ========================================

# Start REPL
repl:
	clj

# Clean compiled artifacts
clean:
	rm -rf .cpcache/ .nrepl-port target/

# Help
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Clojure Project Template - Make Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "🔧 Setup:"
	@echo "  make nrepl                - Start nREPL server (auto-port, writes to .nrepl-port)"
	@echo "  make mcp-configure        - Configure MCP server in Claude Code"
	@echo "  make mcp-run              - Run MCP server (for testing)"
	@echo "  make mcp-remove           - Remove MCP server from Claude Code"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  make runtests             - Run tests with watcher"
	@echo "  make runtests-once        - Run tests once with fail-fast"
	@echo ""
	@echo "🚀 Development:"
	@echo "  make repl                 - Start basic REPL"
	@echo "  make clean                - Clean compiled artifacts"
	@echo "  make help                 - Show this help"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

.PHONY: nrepl mcp-configure mcp-remove mcp-run runtests runtests-once repl clean help

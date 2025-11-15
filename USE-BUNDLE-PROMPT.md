# Prompt: Use M2 Bundle in Your Project

Copy and paste this prompt into Claude Code Web to use the pre-built dependency bundle in your reddit-scraper project:

---

## Prompt for Claude Code Web

I need to set up my Clojure project to use a pre-built Maven dependency cache so I can run tests without internet access to Maven Central.

**Context:**
- I'm working on the `reddit-scraper-fulcro/server2` project
- All Maven dependencies have been pre-built into a bundle
- The bundle is available at: https://github.com/realgenekim/claude-code-web-m2builder/releases/download/m2-bundles/m2-reddit-scraper-server2-complete.tar.gz

**Please help me:**

1. **Download and extract the dependency bundle:**
   ```bash
   # Download the 24 MB bundle (contains 129 JARs)
   curl -L -O https://github.com/realgenekim/claude-code-web-m2builder/releases/download/m2-bundles/m2-reddit-scraper-server2-complete.tar.gz

   # Extract to a cache directory
   mkdir -p ~/.m2-cache
   tar xzf m2-reddit-scraper-server2-complete.tar.gz -C ~/.m2-cache/

   # Verify extraction
   find ~/.m2-cache/m2-reddit-scraper-server2-complete -name "*.jar" | wc -l
   ```

2. **Verify the bundle contains key dependencies:**
   ```bash
   # Check for test framework
   find ~/.m2-cache/m2-reddit-scraper-server2-complete -name "kaocha*.jar"

   # Check for web server
   find ~/.m2-cache/m2-reddit-scraper-server2-complete -name "http-kit*.jar"

   # Check for routing
   find ~/.m2-cache/m2-reddit-scraper-server2-complete -name "reitit-core*.jar"
   ```

3. **Try running the tests using the cached dependencies:**
   ```bash
   cd /path/to/reddit-scraper-fulcro/server2

   # Run tests with the cached M2 repository
   clojure -Sdeps '{:mvn/local-repo "'$HOME'/.m2-cache/m2-reddit-scraper-server2-complete"}' \
           -M:run-tests
   ```

4. **If tests fail due to missing git dependencies**, help me understand which ones need to be resolved:
   - `genek/logging` (git)
   - `browser-reload/browser-reload` (git)
   - `io.github.clojure/tools.build` (git)

5. **Document what worked and what didn't** so we know if the bundle is complete enough for offline testing.

**Expected outcome:**
- Bundle downloads successfully (24 MB)
- Extracts to show ~129 JAR files
- Clojure can find and load the Maven dependencies
- Tests either run successfully or show specific missing git/local dependencies

---

## Alternative: Test with a Simple Project

If you want to test the bundle system with a simpler example first, try this:

**Prompt for Claude Code Web (Simple Test):**

I want to test using a pre-built Maven dependency cache with a simple Clojure web application.

1. **Download the web-stack bundle** (contains Ring, Compojure, Reitit, Cheshire):
   ```bash
   curl -L -O https://github.com/realgenekim/claude-code-web-m2builder/releases/download/m2-bundles/m2-web-stack.tar.gz

   mkdir -p ~/.m2-cache
   tar xzf m2-web-stack.tar.gz -C ~/.m2-cache/
   ```

2. **Create a simple test project:**
   ```bash
   mkdir -p /tmp/test-web-app
   cd /tmp/test-web-app

   cat > deps.edn <<'EOF'
   {:deps {ring/ring-core {:mvn/version "1.12.2"}
           ring/ring-jetty-adapter {:mvn/version "1.12.2"}
           compojure/compojure {:mvn/version "1.7.1"}
           cheshire/cheshire {:mvn/version "5.12.0"}}}
   EOF

   cat > hello.clj <<'EOF'
   (ns hello
     (:require [ring.adapter.jetty :as jetty]
               [compojure.core :refer [defroutes GET]]
               [compojure.route :as route]
               [cheshire.core :as json]))

   (defroutes app
     (GET "/" []
       {:status 200
        :headers {"Content-Type" "application/json"}
        :body (json/generate-string {:message "Hello from cached dependencies!"
                                      :status "working"})})
     (route/not-found "Not Found"))

   (defn -main []
     (println "Starting server on port 3000...")
     (jetty/run-jetty app {:port 3000 :join? false}))
   EOF
   ```

3. **Run the app using ONLY cached dependencies** (no Maven Central access):
   ```bash
   clojure -Sdeps '{:mvn/local-repo "'$HOME'/.m2-cache/m2-web-stack"}' \
           -M -m hello
   ```

4. **Test the endpoint** (in another terminal):
   ```bash
   curl http://localhost:3000/
   # Should return: {"message":"Hello from cached dependencies!","status":"working"}
   ```

**This proves the bundle system works end-to-end without any internet access to Maven Central!**

---

## Quick Bundle Reference

Available pre-built bundles:

| Bundle | Size | JARs | Use Case |
|--------|------|------|----------|
| `m2-reddit-scraper-server2-complete` | 24 MB | 129 | Your full project + all aliases |
| `m2-web-stack` | 17 MB | 98 | Ring + Reitit + Cheshire |
| `m2-gcs-client` | 47 MB | 81 | Google Cloud Storage |
| `m2-clojure-minimal` | 5 MB | 3 | Pure Clojure stdlib |

All at: https://github.com/realgenekim/claude-code-web-m2builder/releases/tag/m2-bundles

---

## Troubleshooting

**If you get "Could not find artifact" errors:**
1. Check the bundle was extracted: `ls -la ~/.m2-cache/`
2. Verify JARs are present: `find ~/.m2-cache/m2-* -name "*.jar" | head -20`
3. Check the artifact name in the error matches what's in your deps.edn
4. Remember: Git dependencies and local dependencies are NOT in the bundle

**If you want to request a custom bundle:**
Create a branch named `claude/bundle-request-{your-bundle-name}-{timestamp}` and the system will automatically build it!

(ns user
  "Development namespace for REPL utilities.
  This namespace is automatically loaded when you start a REPL."
  (:require [clojure.tools.namespace.repl :refer [refresh]]
            [m2builder.core :as core]
            [m2builder.bundle :as bundle]))

(defn reset
  "Reload all changed namespaces."
  []
  (refresh))

(comment
  ;; List available bundles
  (bundle/list-bundles)

  ;; Build a bundle (for testing, use clojure-minimal - it's fast)
  (bundle/build-bundle {:bundle-id "clojure-minimal"
                        :upload? false
                        :cleanup? false})

  ;; Reload changed code
  (reset)
  )

(println "Welcome to M2 Bundler REPL!")
(println "Useful commands:")
(println "  (reset)                  - Reload all changed namespaces")
(println "  (bundle/list-bundles)    - List available bundles")
(println "  (bundle/build-bundle {}) - Build a bundle")

(ns m2builder.core
  "M2 Bundler - Build and distribute Maven dependency bundles for sandboxed environments"
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.string :as str]
            [m2builder.bundle :as bundle]))

(defn -main
  "CLI entry point"
  [& args]
  (let [[command & rest-args] args]
    (case command
      "build-bundle" (apply bundle/build-bundle-cli rest-args)
      (println "Unknown command:" command))))

(comment
  ;; REPL experiments

  ;; List available bundles
  (bundle/list-bundles)

  ;; Build a bundle
  (bundle/build-bundle {:bundle-id "clojure-minimal"})

  )

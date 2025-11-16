(ns m2builder.bundle
  "Bundle building - create M2 caches from dependency definitions"
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.string :as str]
            [clojure.java.shell :as sh])
  (:import [java.io File]
           [java.time Instant]))

(def bundles-dir "bundles")
(def gcs-bucket "gs://gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd")
(def gcs-m2-path (str gcs-bucket "/m2"))

(defn list-bundles
  "List all available bundle definitions"
  []
  (->> (file-seq (io/file bundles-dir))
       (filter #(.endsWith (.getName %) ".edn"))
       (map (fn [f]
              (let [bundle-def (edn/read-string (slurp f))]
                {:file (.getName f)
                 :bundle-id (:bundle-id bundle-def)
                 :description (:description bundle-def)
                 :size-estimate-mb (:size-estimate-mb bundle-def)})))))

(defn read-bundle-def
  "Read bundle definition from EDN file"
  [bundle-id]
  (let [bundle-file (io/file bundles-dir (str bundle-id ".edn"))]
    (when (.exists bundle-file)
      (edn/read-string (slurp bundle-file)))))

(defn create-temp-m2-dir
  "Create temporary M2 directory for bundle"
  [bundle-id]
  (let [timestamp (System/currentTimeMillis)
        temp-dir (io/file "/tmp" (str "m2-" bundle-id "-" timestamp))]
    (.mkdirs temp-dir)
    (.getAbsolutePath temp-dir)))

(defn download-deps
  "Download dependencies to temp M2 directory using clojure CLI"
  [bundle-def m2-dir]
  (let [deps-map (:deps bundle-def)
        temp-project-dir (str "/tmp/clj-project-" (System/currentTimeMillis))
        temp-deps-file (io/file temp-project-dir "deps.edn")
        deps-edn-content (pr-str {:deps deps-map})]

    ;; Create temp project directory
    (.mkdirs (io/file temp-project-dir))

    ;; Write deps.edn to temp directory
    (spit temp-deps-file deps-edn-content)

    (println "Downloading dependencies to" m2-dir "...")
    (println "  Using deps:" (keys deps-map))

    ;; Run clojure -P from temp directory to download deps
    (let [result (sh/sh "clojure"
                        "-Sdeps" (str "{:mvn/local-repo \"" m2-dir "\"}")
                        "-Srepro"
                        "-Sforce"
                        "-P"
                        :dir temp-project-dir)]

      (when-not (zero? (:exit result))
        (throw (ex-info "Failed to download dependencies"
                        {:exit-code (:exit result)
                         :stderr (:err result)
                         :stdout (:out result)})))

      ;; Clean up temp directory
      (sh/sh "rm" "-rf" temp-project-dir)

      ;; Count JARs
      (let [jar-count (->> (file-seq (io/file m2-dir))
                           (filter #(.endsWith (.getName %) ".jar"))
                           count)]
        (println "  ✓ Downloaded" jar-count "JAR files")
        jar-count))))

(def clojure-versions-to-bundle
  "Common Clojure versions to include in every bundle for CLI compatibility"
  ["1.11.1" "1.11.3" "1.12.0" "1.12.3"])

(defn ensure-clojure-versions
  "Ensure multiple Clojure versions are in the M2 cache for CLI compatibility.
   
  This fixes issues where the Clojure CLI tool itself requires a different
  version than what's in the project deps.edn."
  [m2-dir]
  (println "Ensuring Clojure CLI versions are bundled...")
  (doseq [version clojure-versions-to-bundle]
    (let [version-dir (io/file m2-dir "org" "clojure" "clojure" version)]
      (when-not (and (.exists version-dir)
                     (some #(.endsWith (.getName %) ".jar") (.listFiles version-dir)))
        (println "  Downloading Clojure" version "...")
        (let [temp-project-dir (str "/tmp/clj-" version "-" (System/currentTimeMillis))
              deps-edn-content (pr-str {:deps {'org.clojure/clojure {:mvn/version version}}})]
          ;; Create temp project
          (.mkdirs (io/file temp-project-dir))
          (spit (io/file temp-project-dir "deps.edn") deps-edn-content)

          ;; Download
          (let [result (sh/sh "clojure"
                              "-Sdeps" (str "{:mvn/local-repo \"" m2-dir "\"}")
                              "-Srepro" "-Sforce" "-P"
                              :dir temp-project-dir)]
            (when-not (zero? (:exit result))
              (println "    Warning: Failed to download Clojure" version)))

          ;; Clean up temp project
          (sh/sh "rm" "-rf" temp-project-dir)))))

  ;; Report what we have
  (let [clj-dir (io/file m2-dir "org" "clojure" "clojure")
        versions (when (.exists clj-dir) (vec (.list clj-dir)))]
    (println "  ✓ Clojure versions bundled:" versions)))

(defn create-tarball
  "Create compressed tarball from M2 directory"
  [m2-dir bundle-id timestamp]
  (let [tarball-path (str "/tmp/m2-" bundle-id "-" timestamp ".tar.gz")]
    (println "Creating tarball...")
    (println "  From:" m2-dir)
    (println "  To:" tarball-path)

    (let [result (sh/sh "tar" "-czf" tarball-path
                        "-C" m2-dir
                        ".")]
      (when-not (zero? (:exit result))
        (throw (ex-info "Failed to create tarball"
                        {:exit-code (:exit result)
                         :stderr (:err result)})))

      (let [size-bytes (.length (io/file tarball-path))
            size-mb (/ size-bytes 1024.0 1024.0)]
        (println (format "  ✓ Created: %.1f MB" size-mb))
        {:tarball-path tarball-path
         :size-bytes size-bytes
         :size-mb size-mb}))))

(defn upload-to-gcs
  "Upload tarball to GCS bucket"
  [tarball-path bundle-id timestamp]
  (let [gcs-versioned-path (str gcs-m2-path "/" bundle-id "-" timestamp ".tar.gz")
        gcs-latest-path (str gcs-m2-path "/" bundle-id "-latest.tar.gz")]

    (println "Uploading to GCS...")
    (println "  Versioned:" gcs-versioned-path)
    (println "  Latest:" gcs-latest-path)

    ;; Upload versioned
    (let [result (sh/sh "gsutil" "-q" "cp" tarball-path gcs-versioned-path)]
      (when-not (zero? (:exit result))
        (throw (ex-info "Failed to upload to GCS"
                        {:exit-code (:exit result)
                         :stderr (:err result)}))))

    ;; Upload latest
    (let [result (sh/sh "gsutil" "-q" "cp" tarball-path gcs-latest-path)]
      (when-not (zero? (:exit result))
        (throw (ex-info "Failed to upload latest to GCS"
                        {:exit-code (:exit result)
                         :stderr (:err result)}))))

    (println "  ✓ Uploaded")

    {:versioned-url (str "https://storage.googleapis.com/"
                         (subs gcs-bucket 5) ;; remove "gs://"
                         "/m2/" bundle-id "-" timestamp ".tar.gz")
     :latest-url (str "https://storage.googleapis.com/"
                      (subs gcs-bucket 5)
                      "/m2/" bundle-id "-latest.tar.gz")}))

(defn upload-metadata
  "Upload bundle metadata to GCS"
  [bundle-id timestamp metadata]
  (let [metadata-file (io/file "/tmp" (str "metadata-" timestamp ".json"))
        metadata-json (pr-str metadata)
        gcs-metadata-path (str gcs-m2-path "/metadata/" bundle-id "-" timestamp ".json")
        gcs-metadata-latest-path (str gcs-m2-path "/metadata/" bundle-id "-latest.json")]

    (spit metadata-file metadata-json)

    ;; Upload versioned metadata
    (sh/sh "gsutil" "-q" "cp" (.getAbsolutePath metadata-file) gcs-metadata-path)

    ;; Upload latest metadata
    (sh/sh "gsutil" "-q" "cp" (.getAbsolutePath metadata-file) gcs-metadata-latest-path)

    (.delete metadata-file)))

(defn cleanup
  "Clean up temporary files"
  [m2-dir tarball-path]
  (println "Cleaning up temporary files...")

  ;; Delete M2 directory
  (when m2-dir
    (sh/sh "rm" "-rf" m2-dir))

  ;; Delete tarball
  (when tarball-path
    (.delete (io/file tarball-path)))

  (println "  ✓ Cleaned up"))

(defn build-bundle
  "Build M2 bundle from bundle definition

  Options:
    :bundle-id - ID of bundle to build (required)
    :upload?   - Upload to GCS? (default: true)
    :cleanup?  - Clean up temp files? (default: true)"
  [{:keys [bundle-id upload? cleanup?]
    :or {upload? true cleanup? true}}]

  (println "════════════════════════════════════════════════════════════")
  (println "Building M2 Bundle:" bundle-id)
  (println "════════════════════════════════════════════════════════════")

  (let [bundle-def (read-bundle-def bundle-id)]
    (when-not bundle-def
      (throw (ex-info "Bundle not found" {:bundle-id bundle-id})))

    (let [timestamp (System/currentTimeMillis)
          m2-dir (create-temp-m2-dir bundle-id)
          start-time (System/currentTimeMillis)]

      (try
        ;; Download dependencies
        (let [_ (download-deps bundle-def m2-dir)

              ;; Ensure common Clojure versions are bundled for CLI compatibility
              _ (ensure-clojure-versions m2-dir)

              ;; Recount JARs after adding Clojure versions
              jar-count (->> (file-seq (io/file m2-dir))
                             (filter #(.endsWith (.getName %) ".jar"))
                             count)]

          ;; Create tarball
          (let [{:keys [tarball-path size-mb size-bytes]} (create-tarball m2-dir bundle-id timestamp)]

            ;; Upload to GCS
            (let [urls (when upload?
                         (upload-to-gcs tarball-path bundle-id timestamp))]

              ;; Calculate build time
              (let [build-time-ms (- (System/currentTimeMillis) start-time)
                    build-time-sec (/ build-time-ms 1000.0)
                    metadata {:bundle-id bundle-id
                              :timestamp timestamp
                              :timestamp-iso (.toString (Instant/ofEpochMilli timestamp))
                              :size-bytes size-bytes
                              :size-mb size-mb
                              :artifact-count jar-count
                              :build-time-seconds build-time-sec
                              :versioned-url (:versioned-url urls)
                              :latest-url (:latest-url urls)}]

                ;; Upload metadata
                (when upload?
                  (upload-metadata bundle-id timestamp metadata))

                ;; Clean up
                (when cleanup?
                  (cleanup m2-dir tarball-path))

                (println "")
                (println "════════════════════════════════════════════════════════════")
                (println "✅ Bundle built successfully!")
                (println "════════════════════════════════════════════════════════════")
                (println)
                (println "Bundle Details:")
                (println (format "  Size:       %.1f MB" size-mb))
                (println (format "  JARs:       %d" jar-count))
                (println (format "  Build time: %.1f seconds" build-time-sec))
                (when upload?
                  (println)
                  (println "Download URLs:")
                  (println "  Versioned:" (:versioned-url urls))
                  (println "  Latest:   " (:latest-url urls)))
                (println)

                metadata))))

        (catch Exception e
          (when cleanup?
            (cleanup m2-dir nil))
          (throw e))))))

(defn build-bundle-cli
  "CLI wrapper for build-bundle"
  [bundle-id]
  (build-bundle {:bundle-id bundle-id}))

(comment
  ;; REPL experiments

  ;; List available bundles
  (list-bundles)

  ;; Read a bundle definition
  (read-bundle-def "clojure-minimal")

  ;; Build clojure-minimal bundle (fast, for testing)
  (build-bundle {:bundle-id "clojure-minimal"
                 :upload? false
                 :cleanup? false})

  ;; Build server2 bundle
  (build-bundle {:bundle-id "reddit-scraper-server2"}))

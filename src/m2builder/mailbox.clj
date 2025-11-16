(ns m2builder.mailbox
  "Mailbox message handling - read/write EDN request/response messages via GCS"
  (:require [clojure.java.io :as io]
            [clojure.edn :as edn]
            [clojure.string :as str]
            [clojure.java.shell :as sh])
  (:import [java.time Instant]))

;; GCS paths
(def gcs-bucket "gs://gene-m2-bundler-f9a6d1b69e17b97714b0e9cbe141e4ac2c14b18ad6cd")
(def gcs-mailbox-path (str gcs-bucket "/mailbox"))
(def gcs-requests-path (str gcs-mailbox-path "/requests"))
(def gcs-responses-path (str gcs-mailbox-path "/responses"))
(def gcs-processed-path (str gcs-mailbox-path "/processed"))

;; Message schema constants
(def schema-version "1.0.0")

;; Helper functions

(defn current-timestamp-iso
  "Get current timestamp in ISO 8601 format"
  []
  (.toString (Instant/now)))

(defn gsutil-ls
  "List GCS objects with optional prefix"
  ([gcs-path]
   (let [result (sh/sh "gsutil" "ls" gcs-path)]
     (when (zero? (:exit result))
       (->> (str/split-lines (:out result))
            (remove str/blank?)))))
  ([gcs-path pattern]
   (let [result (sh/sh "gsutil" "ls" (str gcs-path pattern))]
     (when (zero? (:exit result))
       (->> (str/split-lines (:out result))
            (remove str/blank?))))))

(defn gsutil-cat
  "Read GCS object contents"
  [gcs-path]
  (let [result (sh/sh "gsutil" "cat" gcs-path)]
    (when (zero? (:exit result))
      (:out result))))

(defn gsutil-cp
  "Copy to GCS"
  [local-path gcs-path]
  (let [result (sh/sh "gsutil" "-q" "cp" local-path gcs-path)]
    (zero? (:exit result))))

(defn gsutil-mv
  "Move GCS object"
  [from-path to-path]
  (let [result (sh/sh "gsutil" "-q" "mv" from-path to-path)]
    (zero? (:exit result))))

;; Request handling

(defn list-requests
  "List all pending requests in mailbox

  Returns list of maps with :gcs-path, :session-id, :request-id"
  []
  (when-let [request-files (gsutil-ls (str gcs-requests-path "/**/*.edn"))]
    (->> request-files
         (map (fn [path]
                (let [parts (str/split path #"/")
                      filename (last parts)
                      session-id (nth parts (- (count parts) 2))
                      request-id (str/replace filename #"\.edn$" "")]
                  {:gcs-path path
                   :session-id session-id
                   :request-id request-id})))
         (vec))))

(defn read-request
  "Read and parse request EDN from GCS

  Args:
    gcs-path - Full GCS path to request file

  Returns parsed EDN map or nil if error"
  [gcs-path]
  (when-let [content (gsutil-cat gcs-path)]
    (try
      (edn/read-string content)
      (catch Exception e
        (println "Error parsing request:" (.getMessage e))
        nil))))

(defn parse-request
  "Extract key fields from request

  Returns map with :bundle-id, :session-id, :message-id, :payload"
  [request]
  {:bundle-id (get-in request [:payload :bundle-id])
   :session-id (:session-id request)
   :message-id (:message-id request)
   :payload (:payload request)})

;; Response handling

(defn create-response
  "Create response EDN structure

  Args:
    session-id - Session ID from request
    message-id - Message ID from request (for correlation)
    status - :success, :error, or :in-progress
    payload - Response payload map (bundle-url, size, etc.)
    error - Optional error message if status = :error

  Returns EDN map"
  [session-id message-id status payload & [error]]
  {:schema-version schema-version
   :timestamp (current-timestamp-iso)
   :from "m2-bundler-service"
   :session-id session-id
   :message-id message-id
   :type :response
   :status status
   :payload payload
   :error error})

(defn write-response
  "Write response to GCS mailbox

  Args:
    session-id - Session ID
    request-id - Request ID (for filename)
    response - Response EDN map

  Returns true if successful"
  [session-id request-id response]
  (let [temp-file (io/file "/tmp" (str "response-" request-id ".edn"))
        gcs-response-path (str gcs-responses-path "/" session-id "/" request-id ".edn")]

    ;; Write to temp file
    (spit temp-file (pr-str response))

    ;; Upload to GCS
    (let [success? (gsutil-cp (.getAbsolutePath temp-file) gcs-response-path)]

      ;; Clean up temp file
      (.delete temp-file)

      (when success?
        (println "✓ Response written to:" gcs-response-path))

      success?)))

;; Request processing

(defn archive-request
  "Move processed request to archive

  Args:
    gcs-request-path - Full GCS path to request file
    session-id - Session ID
    request-id - Request ID

  Returns true if successful"
  [gcs-request-path session-id request-id]
  (let [archive-path (str gcs-processed-path "/" session-id "/" request-id ".edn")]
    (gsutil-mv gcs-request-path archive-path)))

(defn process-request
  "Process a single request: build bundle and send response

  Args:
    request-info - Map from list-requests with :gcs-path, :session-id, :request-id

  Side effects:
    - Builds M2 bundle
    - Uploads to GCS
    - Writes response
    - Archives request

  Returns response map or nil if error"
  [request-info]
  (let [{:keys [gcs-path session-id request-id]} request-info]
    (println "")
    (println "════════════════════════════════════════════════════════════")
    (println "Processing Request:" request-id)
    (println "Session:" session-id)
    (println "════════════════════════════════════════════════════════════")

    (try
      ;; Read request
      (if-let [request (read-request gcs-path)]
        (let [{:keys [bundle-id]} (parse-request request)]
          (println "Bundle requested:" bundle-id)

          ;; Build bundle
          (require '[m2builder.bundle :as bundle])
          (let [result ((resolve 'bundle/build-bundle) {:bundle-id bundle-id})

                ;; Create response payload
                payload {:bundle-url (:versioned-url result)
                         :latest-url (:latest-url result)
                         :bundle-size-mb (:size-mb result)
                         :artifact-count (:artifact-count result)
                         :build-time-seconds (:build-time-seconds result)
                         :timestamp-iso (:timestamp-iso result)}

                ;; Create response
                response (create-response session-id request-id :success payload)]

            ;; Write response
            (write-response session-id request-id response)

            ;; Archive request
            (archive-request gcs-path session-id request-id)

            (println "✓ Request processed successfully")
            (println "")

            response))

        ;; Request parse error
        (let [error-response (create-response session-id request-id :error {} "Failed to parse request")]
          (write-response session-id request-id error-response)
          (archive-request gcs-path session-id request-id)
          (println "✗ Request parse error")
          error-response))

      (catch Exception e
        (println "✗ Error processing request:" (.getMessage e))
        (.printStackTrace e)

        ;; Send error response
        (let [error-response (create-response session-id request-id :error {} (.getMessage e))]
          (write-response session-id request-id error-response)
          (archive-request gcs-path session-id request-id)
          error-response)))))

;; CLI entry points

(defn poll-requests
  "Continuously poll for new requests and process them

  Args:
    interval-seconds - How often to check (default: 30)

  Runs forever (use Ctrl-C to stop)"
  ([] (poll-requests 30))
  ([interval-seconds]
   (println "Starting request polling...")
   (println "Checking every" interval-seconds "seconds")
   (println "Press Ctrl-C to stop")
   (println "")

   (loop []
     (try
       ;; List pending requests
       (if-let [requests (list-requests)]
         (do
           (println "[" (current-timestamp-iso) "] Found" (count requests) "pending request(s)")

           ;; Process each request
           (doseq [req requests]
             (process-request req)))

         ;; No requests
         (println "[" (current-timestamp-iso) "] No pending requests"))

       (catch Exception e
         (println "Error in polling loop:" (.getMessage e))
         (.printStackTrace e)))

     ;; Sleep
     (Thread/sleep (* interval-seconds 1000))

     ;; Continue loop
     (recur))))

(defn process-request-cli
  "CLI wrapper for process-request

  Args:
    gcs-request-path - Full GCS path to request file"
  [gcs-request-path]
  (let [parts (str/split gcs-request-path #"/")
        session-id (nth parts (- (count parts) 2))
        request-id (-> (last parts)
                      (str/replace #"\.edn$" ""))]
    (process-request {:gcs-path gcs-request-path
                      :session-id session-id
                      :request-id request-id})))

(comment
  ;; REPL experiments

  ;; List pending requests
  (list-requests)

  ;; Read a specific request
  (def req (first (list-requests)))
  (read-request (:gcs-path req))

  ;; Process a request
  (process-request (first (list-requests)))

  ;; Create and write a test response
  (def test-response
    (create-response "test-session-123" "req-456" :success
                     {:bundle-url "https://..."
                      :bundle-size-mb 24.4}))

  (write-response "test-session-123" "req-456" test-response)

  ;; Poll for requests (runs forever)
  (poll-requests 10)  ; Check every 10 seconds

  )

(ns m2builder.bundle-test
  (:require [clojure.test :refer [deftest testing is]]
            [m2builder.bundle :as bundle]))

(deftest list-bundles-test
  (testing "list-bundles returns available bundle definitions"
    (let [bundles (bundle/list-bundles)]
      (is (seq? bundles))
      (is (every? map? bundles))
      (is (some #(= (:bundle-id %) "clojure-minimal") bundles)))))

(deftest read-bundle-def-test
  (testing "read-bundle-def returns valid bundle map"
    (let [bundle-def (bundle/read-bundle-def "clojure-minimal")]
      (is (map? bundle-def))
      (is (contains? bundle-def :deps))
      (is (contains? bundle-def :bundle-id)))))

(deftest clojure-versions-to-bundle-test
  (testing "clojure-versions-to-bundle contains expected versions"
    (is (vector? bundle/clojure-versions-to-bundle))
    (is (some #(= % "1.11.1") bundle/clojure-versions-to-bundle))
    (is (some #(= % "1.11.3") bundle/clojure-versions-to-bundle))
    (is (some #(= % "1.12.0") bundle/clojure-versions-to-bundle))
    (is (some #(= % "1.12.3") bundle/clojure-versions-to-bundle))))

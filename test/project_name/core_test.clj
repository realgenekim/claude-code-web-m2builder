(ns project-name.core-test
  (:require [clojure.test :refer [deftest is testing]]
            [project-name.core :as core]))

(deftest greet-test
  (testing "greet function returns proper greeting"
    (is (= "Hello, World!" (core/greet "World")))
    (is (= "Hello, Clojure!" (core/greet "Clojure"))))

  (testing "greet handles empty string"
    (is (= "Hello, !" (core/greet "")))))

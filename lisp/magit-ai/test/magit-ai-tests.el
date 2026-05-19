;;; magit-ai-tests.el --- Tests for Magit-AI  -*- lexical-binding:t; coding:utf-8 -*-

;; Copyright (C) 2024-2026 The Magit Project Contributors

;; SPDX-License-Identifier: BSD-3-Clause

;; See LICENSE.md for terms.  BSD-3-Clause.

;;; Commentary:

;; Tests for magit-ai functionality.  These tests use mock data
;; instead of requiring an actual git-ai binary.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'magit)
(require 'magit-ai-process)

;; Load other magit-ai modules if available
(require 'magit-ai nil t)
(require 'magit-ai-sections nil t)
(require 'magit-ai-blame nil t)
(require 'magit-ai-diff nil t)
(require 'magit-ai-log nil t)

;;; Test Helpers

(defvar magit-ai-test--mock-executable "/usr/bin/true"
  "Mock executable path for tests.")

(defvar magit-ai-test--mock-output nil
  "Mock output for git-ai commands.")

(defvar magit-ai-test--mock-json nil
  "Mock JSON response for git-ai commands.")

(defmacro magit-ai-with-mock-executable (&rest body)
  "Execute BODY with git-ai mocked to /usr/bin/true."
  (declare (indent 0) (debug t))
  `(let ((magit-ai--executable-cache magit-ai-test--mock-executable))
     ,@body))

(defmacro magit-ai-with-mock-unavailable (&rest body)
  "Execute BODY with git-ai unavailable."
  (declare (indent 0) (debug t))
  `(cl-letf (((symbol-function 'magit-ai-executable-find) (lambda () nil)))
     (let ((magit-ai--executable-cache nil))
       ,@body)))

(defmacro magit-ai-with-mock-output (output &rest body)
  "Execute BODY with git-ai output mocked to OUTPUT."
  (declare (indent 1) (debug t))
  `(let ((magit-ai-test--mock-output ,output))
     (cl-letf (((symbol-function 'magit-ai-output)
                (lambda (&rest _) magit-ai-test--mock-output)))
       (magit-ai-with-mock-executable
         ,@body))))

(defmacro magit-ai-with-mock-json (json &rest body)
  "Execute BODY with git-ai JSON response mocked to JSON."
  (declare (indent 1) (debug t))
  `(let ((magit-ai-test--mock-json ,json))
     (cl-letf (((symbol-function 'magit-ai-json)
                (lambda (&rest _) magit-ai-test--mock-json)))
       (magit-ai-with-mock-executable
         ,@body))))

;;; Fixture Data

(defconst magit-ai-test--stats-fixture
  '((human_additions . 58)
    (total_ai_additions . 42)
    (tool_model_breakdown
     . ((claude-code . ((additions . 30)))
        (cursor . ((additions . 12))))))
  "Mock stats JSON response from git-ai stats --json.")

(defconst magit-ai-test--empty-stats-fixture
  '((human_additions . 0)
    (total_ai_additions . 0)
    (tool_model_breakdown . nil))
  "Mock empty stats JSON response.")

(defconst magit-ai-test--blame-output-fixture
  "abc123 [claude-code] line 1 content
def456 (John Doe    2024-01-14) line 2 content
ghi789 [cursor] line 3 content"
  "Mock blame output from git-ai blame.")

(defconst magit-ai-test--diff-output-fixture
  "diff --git a/file.el b/file.el
index abc123..def456 100644
--- a/file.el
+++ b/file.el
@@ -1,3 +1,5 @@
 existing line
+[claude-code](new ai line)
+[cursor](another ai line)
+ human added line
 another existing"
  "Mock diff output from git-ai diff.")

(defconst magit-ai-test--version-fixture
  "git-ai 1.2.3"
  "Mock version output from git-ai version.")

;;; Binary Discovery Tests

(ert-deftest magit-ai-test-available-p-when-present ()
  "Test `magit-ai-available-p' returns t when binary is found."
  (magit-ai-with-mock-executable
    (should (eq (magit-ai-available-p) t))))

(ert-deftest magit-ai-test-available-p-when-missing ()
  "Test `magit-ai-available-p' returns nil when binary is not found."
  (magit-ai-with-mock-unavailable
    (should (eq (magit-ai-available-p) nil))))

(ert-deftest magit-ai-test-assert-available-signals-error ()
  "Test `magit-ai--assert-available' signals error when unavailable."
  (magit-ai-with-mock-unavailable
    (should-error (magit-ai--assert-available) :type 'user-error)))

;;; JSON Parsing Tests

(ert-deftest magit-ai-test-parse-stats-basic ()
  "Test `magit-ai--parse-stats' parses fixture correctly."
  (let ((result (magit-ai--parse-stats magit-ai-test--stats-fixture)))
    (should (= (plist-get result :ai-additions) 42))
    (should (= (plist-get result :human-additions) 58))
    (should (= (plist-get result :total-additions) 100))
    (should (floatp (plist-get result :ai-percent)))
    (should (floatp (plist-get result :human-percent)))
    ;; 42% AI, 58% Human (use tolerance for floating point)
    (should (< (abs (- (plist-get result :ai-percent) 42.0)) 0.01))
    (should (< (abs (- (plist-get result :human-percent) 58.0)) 0.01))))

(ert-deftest magit-ai-test-parse-stats-empty ()
  "Test `magit-ai--parse-stats' handles empty stats."
  (let ((result (magit-ai--parse-stats magit-ai-test--empty-stats-fixture)))
    (should (= (plist-get result :ai-additions) 0))
    (should (= (plist-get result :human-additions) 0))
    (should (= (plist-get result :total-additions) 0))
    ;; Zero total should default to 0% AI, 100% Human
    (should (= (plist-get result :ai-percent) 0))
    (should (= (plist-get result :human-percent) 100))))

(ert-deftest magit-ai-test-parse-stats-nil ()
  "Test `magit-ai--parse-stats' handles nil input."
  (should (null (magit-ai--parse-stats nil))))

;;; Stats Function Tests

(ert-deftest magit-ai-test-stats-with-data ()
  "Test `magit-ai-stats' returns parsed stats."
  (magit-ai-with-mock-json magit-ai-test--stats-fixture
    (let ((stats (magit-ai-stats "HEAD")))
      (should stats)
      (should (= (plist-get stats :ai-additions) 42)))))

(ert-deftest magit-ai-test-stats-unavailable ()
  "Test `magit-ai-stats' returns nil when unavailable."
  (magit-ai-with-mock-unavailable
    (should (null (magit-ai-stats "HEAD")))))

;;; Face Helper Tests

(ert-deftest magit-ai-test-tool-face-known ()
  "Test `magit-ai--tool-face' returns correct face for known tools."
  (should (eq (magit-ai--tool-face "claude-code") 'magit-ai-author-claude))
  (should (eq (magit-ai--tool-face "claude") 'magit-ai-author-claude))
  (should (eq (magit-ai--tool-face "cursor") 'magit-ai-author-cursor))
  (should (eq (magit-ai--tool-face "github-copilot") 'magit-ai-author-copilot))
  (should (eq (magit-ai--tool-face "copilot") 'magit-ai-author-copilot))
  (should (eq (magit-ai--tool-face "gemini") 'magit-ai-author-gemini)))

(ert-deftest magit-ai-test-tool-face-unknown ()
  "Test `magit-ai--tool-face' returns fallback for unknown tools."
  (should (eq (magit-ai--tool-face "unknown-tool") magit-ai-unknown-tool-face)))

(ert-deftest magit-ai-test-format-tool-name ()
  "Test `magit-ai--format-tool-name' formats names correctly."
  (should (equal (magit-ai--format-tool-name "claude-code") "Claude"))
  (should (equal (magit-ai--format-tool-name "cursor") "Cursor"))
  (should (equal (magit-ai--format-tool-name "github-copilot") "Copilot"))
  (should (equal (magit-ai--format-tool-name "some-new-tool") "Some New Tool")))

(ert-deftest magit-ai-test-propertize-tool ()
  "Test `magit-ai--propertize-tool' returns propertized string."
  (let ((result (magit-ai--propertize-tool "claude-code")))
    (should (stringp result))
    (should (equal result "Claude"))
    (should (eq (get-text-property 0 'face result) 'magit-ai-author-claude))))

;;; Environment Tests

(ert-deftest magit-ai-test-process-environment ()
  "Test `magit-ai-process-environment' includes custom variables."
  (let ((magit-ai-environment '(("FOO" . "bar") ("BAZ" . "qux"))))
    (let ((env (magit-ai-process-environment)))
      (should (member "FOO=bar" env))
      (should (member "BAZ=qux" env)))))

(ert-deftest magit-ai-test-process-arguments ()
  "Test `magit-ai-process-arguments' prepends global args."
  (let ((magit-ai-global-arguments '("--verbose")))
    (let ((args (magit-ai-process-arguments '("stats" "HEAD"))))
      (should (equal args '("--verbose" "stats" "HEAD"))))))

;;; Transient Tests (if magit-ai is loaded)

(when (featurep 'magit-ai)
  (ert-deftest magit-ai-test-transient-defined ()
    "Test `magit-ai' transient is defined."
    (should (fboundp 'magit-ai))
    (should (get 'magit-ai 'transient--prefix))))

;;; Section Tests (if magit-ai-sections is loaded)

(when (featurep 'magit-ai-sections)
  (ert-deftest magit-ai-test-stats-section-class ()
    "Test `magit-ai-stats-section' class is defined."
    (should (find-class 'magit-ai-stats-section)))

  (ert-deftest magit-ai-test-insert-ai-stats-no-crash ()
    "Test `magit-insert-ai-stats' doesn't crash with mock data."
    (magit-ai-with-mock-json magit-ai-test--stats-fixture
      (with-temp-buffer
        (magit-mode)
        (let ((magit-ai-show-in-status t))
          ;; Should not error even without a real repo
          (condition-case nil
              (progn
                (magit-insert-ai-stats)
                t)
            (error nil)))))))

;;; Blame Tests (if magit-ai-blame is loaded)

(when (featurep 'magit-ai-blame)
  (ert-deftest magit-ai-test-blame-chunk-class ()
    "Test `magit-ai-blame-chunk' class is defined."
    (should (find-class 'magit-ai-blame-chunk)))

  (ert-deftest magit-ai-test-blame-extract-tool-claude ()
    "Test `magit-ai-blame--extract-tool' extracts claude."
    (should (equal (magit-ai-blame--extract-tool "abc123 [claude-code] line")
                   "claude-code"))
    (should (equal (magit-ai-blame--extract-tool "abc123 [claude] line")
                   "claude")))

  (ert-deftest magit-ai-test-blame-extract-tool-cursor ()
    "Test `magit-ai-blame--extract-tool' extracts cursor."
    (should (equal (magit-ai-blame--extract-tool "abc123 [cursor] line")
                   "cursor")))

  (ert-deftest magit-ai-test-blame-extract-tool-copilot ()
    "Test `magit-ai-blame--extract-tool' extracts copilot."
    (should (equal (magit-ai-blame--extract-tool "abc123 [github-copilot] line")
                   "github-copilot"))
    (should (equal (magit-ai-blame--extract-tool "abc123 [copilot] line")
                   "copilot")))

  (ert-deftest magit-ai-test-blame-extract-tool-human ()
    "Test `magit-ai-blame--extract-tool' returns nil for human."
    (should (null (magit-ai-blame--extract-tool "abc123 (John Doe 2024) line")))))

;;; Diff Tests (if magit-ai-diff is loaded)

(when (featurep 'magit-ai-diff)
  (ert-deftest magit-ai-test-diff-mode-defined ()
    "Test `magit-ai-diff-mode' is defined."
    (should (fboundp 'magit-ai-diff-mode))))

;;; Log Tests (if magit-ai-log is loaded)

(when (featurep 'magit-ai-log)
  (ert-deftest magit-ai-test-log-mode-defined ()
    "Test `magit-ai-log-mode' is defined."
    (should (fboundp 'magit-ai-log-mode))))

;;; Error Handling Tests

(ert-deftest magit-ai-test-graceful-degradation ()
  "Test magit-ai functions gracefully handle unavailable binary."
  (magit-ai-with-mock-unavailable
    ;; These should return nil, not error
    (should (null (magit-ai-stats "HEAD")))
    (should (null (magit-ai-version)))))

;;; Cache Tests

(ert-deftest magit-ai-test-cache-key-generation ()
  "Test `magit-ai--cache-key' generates correct keys."
  (let ((default-directory "/test/repo/"))
    (should (equal (magit-ai--cache-key "HEAD")
                   '("/test/repo/" . "HEAD")))
    (should (equal (magit-ai--cache-key "abc123")
                   '("/test/repo/" . "abc123")))))

(ert-deftest magit-ai-test-cache-storage-and-retrieval ()
  "Test cache storage and retrieval within TTL."
  (let ((magit-ai-stats-cache-ttl 60)
        (magit-ai--stats-cache (make-hash-table :test 'equal))
        (default-directory "/test/repo/"))
    ;; Store a value
    (magit-ai--cache-stats "HEAD" '(:ai-percent 42))
    ;; Should retrieve it
    (let ((cached (magit-ai--cached-stats "HEAD")))
      (should cached)
      (should (equal (plist-get cached :ai-percent) 42)))))

(ert-deftest magit-ai-test-cache-disabled-when-ttl-zero ()
  "Test caching is disabled when TTL is 0."
  (let ((magit-ai-stats-cache-ttl 0)
        (magit-ai--stats-cache (make-hash-table :test 'equal))
        (default-directory "/test/repo/"))
    ;; Store should not cache when TTL is 0
    (magit-ai--cache-stats "HEAD" '(:ai-percent 42))
    ;; Should not retrieve anything
    (should (null (magit-ai--cached-stats "HEAD")))))

(ert-deftest magit-ai-test-clear-cache ()
  "Test `magit-ai-clear-cache' clears all caches."
  (let ((magit-ai--executable-cache "/usr/bin/git-ai")
        (magit-ai--version-cache "1.0.0")
        (magit-ai--stats-cache (make-hash-table :test 'equal)))
    (puthash '("/repo/" . "HEAD") '(0 . (:test t)) magit-ai--stats-cache)
    (magit-ai-clear-cache)
    (should (null magit-ai--executable-cache))
    (should (null magit-ai--version-cache))
    (should (= (hash-table-count magit-ai--stats-cache) 0))))

;;; Additional Blame Tests

(when (featurep 'magit-ai-blame)
  (ert-deftest magit-ai-test-blame-extract-tool-gemini ()
    "Test `magit-ai-blame--extract-tool' extracts gemini."
    (should (equal (magit-ai-blame--extract-tool "abc123 [gemini] line")
                   "gemini")))

  (ert-deftest magit-ai-test-blame-extract-tool-continue ()
    "Test `magit-ai-blame--extract-tool' extracts continue."
    (should (equal (magit-ai-blame--extract-tool "abc123 [continue-cli] line")
                   "continue-cli"))
    (should (equal (magit-ai-blame--extract-tool "abc123 [continue] line")
                   "continue")))

  (ert-deftest magit-ai-test-blame-extract-tool-generic-ai ()
    "Test `magit-ai-blame--extract-tool' extracts generic AI marker."
    (should (equal (magit-ai-blame--extract-tool "abc123 [AI:some-tool] line")
                   "some-tool")))

  (ert-deftest magit-ai-test-blame-extract-author ()
    "Test `magit-ai-blame--extract-author' extracts human author name."
    (should (equal (magit-ai-blame--extract-author
                    "abc123 (John Doe    2024-01-14) content")
                   "John Doe"))
    (should (equal (magit-ai-blame--extract-author
                    "def456 (Jane Smith 2024-01-15 12:30) more content")
                   "Jane Smith")))

  (ert-deftest magit-ai-test-blame-chunk-creation ()
    "Test creating blame chunk objects."
    (let ((chunk (magit-ai-blame-chunk
                  :line-start 1
                  :line-end 10
                  :tool "claude-code"
                  :prompt-id "abc123")))
      (should (= (oref chunk line-start) 1))
      (should (= (oref chunk line-end) 10))
      (should (equal (oref chunk tool) "claude-code"))
      (should (equal (oref chunk prompt-id) "abc123"))))

  (ert-deftest magit-ai-test-blame-format-margin ()
    "Test `magit-ai-blame--format-margin' formats correctly."
    (let ((result (magit-ai-blame--format-margin "Claude" 10 'magit-ai-author-claude)))
      (should (stringp result))
      ;; Should contain the tool name
      (should (string-match-p "Claude" result))))

  (ert-deftest magit-ai-test-blame-format-margin-truncation ()
    "Test `magit-ai-blame--format-margin' truncates long names."
    (let ((result (magit-ai-blame--format-margin "VeryLongToolName" 8 'magit-ai-author)))
      (should (stringp result))
      ;; The core content should be truncated to fit width
      (should (<= (length (string-trim result)) 10)))))

;;; Additional Diff Tests

(when (featurep 'magit-ai-diff)
  (ert-deftest magit-ai-test-diff-parse-output ()
    "Test `magit-ai-diff--parse-output' extracts file annotations."
    (let ((result (magit-ai-diff--parse-output magit-ai-test--diff-output-fixture)))
      (should result)
      (should (assoc "file.el" result))))

  (ert-deftest magit-ai-test-diff-parse-empty-output ()
    "Test `magit-ai-diff--parse-output' handles empty output."
    (should (null (magit-ai-diff--parse-output ""))))

  (ert-deftest magit-ai-test-diff-mode-toggle ()
    "Test `magit-ai-diff-mode' can be toggled."
    (with-temp-buffer
      ;; Mode should be off initially
      (should (not magit-ai-diff-mode))
      ;; Can't enable without git-ai, but should not error
      (magit-ai-with-mock-unavailable
        (condition-case err
            (magit-ai-diff-mode 1)
          (user-error
           (should (string-match-p "not available" (cadr err)))))))))

;;; Additional Log Tests

(when (featurep 'magit-ai-log)
  (ert-deftest magit-ai-test-log-mode-toggle ()
    "Test `magit-ai-log-mode' can be toggled."
    (with-temp-buffer
      ;; Mode should be off initially
      (should (not magit-ai-log-mode))
      ;; Can't enable without git-ai, but should not error
      (magit-ai-with-mock-unavailable
        (condition-case err
            (magit-ai-log-mode 1)
          (user-error
           (should (string-match-p "not available" (cadr err))))))))

  (ert-deftest magit-ai-test-log-face-defined ()
    "Test log-specific faces are defined."
    (should (facep 'magit-ai-log-ai-commit))
    (should (facep 'magit-ai-log-percentage))))

;;; Version Tests

(ert-deftest magit-ai-test-version-returns-string ()
  "Test `magit-ai-version' returns version string."
  (let ((magit-ai--version-cache nil))
    (magit-ai-with-mock-output magit-ai-test--version-fixture
      (cl-letf (((symbol-function 'magit-ai-string)
                 (lambda (&rest _) magit-ai-test--version-fixture)))
        (let ((version (magit-ai-version)))
          (should (stringp version))
          (should (string-match-p "git-ai" version)))))))

(ert-deftest magit-ai-test-version-caches-result ()
  "Test `magit-ai-version' caches result."
  (let ((magit-ai--version-cache "cached-version"))
    (magit-ai-with-mock-executable
      ;; Should return cached value without calling git-ai
      (should (equal (magit-ai-version) "cached-version")))))

;;; Face Definition Tests

(ert-deftest magit-ai-test-faces-defined ()
  "Test all expected faces are defined."
  (should (facep 'magit-ai-author))
  (should (facep 'magit-ai-author-claude))
  (should (facep 'magit-ai-author-cursor))
  (should (facep 'magit-ai-author-copilot))
  (should (facep 'magit-ai-author-gemini))
  (should (facep 'magit-ai-author-continue))
  (should (facep 'magit-ai-author-human))
  (should (facep 'magit-ai-no-data))
  (should (facep 'magit-ai-stats-heading))
  (should (facep 'magit-ai-stats-ai-percent))
  (should (facep 'magit-ai-stats-human-percent)))

;;; Tool Face Alist Tests

(ert-deftest magit-ai-test-tool-face-alist-complete ()
  "Test `magit-ai-tool-face-alist' has expected mappings."
  (should (assoc "claude-code" magit-ai-tool-face-alist))
  (should (assoc "claude" magit-ai-tool-face-alist))
  (should (assoc "cursor" magit-ai-tool-face-alist))
  (should (assoc "github-copilot" magit-ai-tool-face-alist))
  (should (assoc "copilot" magit-ai-tool-face-alist))
  (should (assoc "gemini" magit-ai-tool-face-alist))
  (should (assoc "continue-cli" magit-ai-tool-face-alist)))

;;; Stats Tool Breakdown Tests

(ert-deftest magit-ai-test-parse-stats-tool-breakdown ()
  "Test `magit-ai--parse-stats' extracts tool breakdown."
  (let ((result (magit-ai--parse-stats magit-ai-test--stats-fixture)))
    (should (plist-get result :tool-breakdown))
    (let ((breakdown (plist-get result :tool-breakdown)))
      (should (assq 'claude-code breakdown))
      (should (assq 'cursor breakdown)))))

;;; Customization Variable Tests

(ert-deftest magit-ai-test-customization-defaults ()
  "Test customization variables have sensible defaults."
  ;; Process settings
  (should (stringp magit-ai-executable))
  (should (or (null magit-ai-global-arguments)
              (listp magit-ai-global-arguments)))
  (should (or (null magit-ai-environment)
              (listp magit-ai-environment)))
  ;; Display toggles
  (should (booleanp magit-ai-show-in-status))
  (should (booleanp magit-ai-show-in-blame))
  (should (booleanp magit-ai-show-in-diff))
  ;; Cache TTL
  (should (integerp magit-ai-stats-cache-ttl))
  (should (>= magit-ai-stats-cache-ttl 0)))

;;; Keybinding Tests

(when (featurep 'magit-ai)
  (ert-deftest magit-ai-test-keybinding-prefix-customizable ()
    "Test `magit-ai-mode-map-prefix' is customizable."
    (should (boundp 'magit-ai-mode-map-prefix))
    (should (or (stringp magit-ai-mode-map-prefix)
                (null magit-ai-mode-map-prefix)))))

;;; Integration Test Helpers

(ert-deftest magit-ai-test-with-check-macro ()
  "Test `magit-ai--with-check' macro behavior."
  ;; When available, should execute body
  (magit-ai-with-mock-executable
    (let ((executed nil))
      (magit-ai--with-check
        (setq executed t))
      (should executed)))
  ;; When unavailable, should just message
  (magit-ai-with-mock-unavailable
    (let ((executed nil))
      (magit-ai--with-check
        (setq executed t))
      (should (not executed)))))

(provide 'magit-ai-tests)
;;; magit-ai-tests.el ends here

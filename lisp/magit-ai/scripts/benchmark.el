;;; benchmark.el --- Benchmark magit-ai functions -*- lexical-binding: t; -*-

;;; Commentary:

;; Benchmarks key magit-ai functions and optionally saves/checks baselines.
;; Usage:
;;   emacs -Q --batch -L . -l scripts/benchmark.el -- run
;;   emacs -Q --batch -L . -l scripts/benchmark.el -- save
;;   emacs -Q --batch -L . -l scripts/benchmark.el -- check

;;; Code:

(require 'cl-lib)
(require 'magit-ai-process)
(require 'magit-ai-blame nil t)

(defvar magit-ai-bench-iterations 10000
  "Number of iterations per benchmark.")

(defvar magit-ai-bench-results nil
  "Alist of (name . seconds) benchmark results.")

(defun magit-ai-bench--record (name thunk)
  "Benchmark THUNK for NAME over `magit-ai-bench-iterations' runs."
  (let ((result (benchmark-run magit-ai-bench-iterations (funcall thunk))))
    (push (cons name (car result)) magit-ai-bench-results)
    (message "  %-40s %8.4fs" name (car result))))

(defun magit-ai-bench--run-all ()
  "Run all benchmarks and populate `magit-ai-bench-results'."
  (setq magit-ai-bench-results nil)
  (message "Running benchmarks (%d iterations each)..." magit-ai-bench-iterations)
  (message "")
  ;; Stats parsing
  (let ((fixture '((human_additions . 58)
                   (total_ai_additions . 42)
                   (tool_model_breakdown
                    . ((claude-code . ((additions . 30)))
                       (cursor . ((additions . 12))))))))
    (magit-ai-bench--record "parse-stats"
      (lambda () (magit-ai--parse-stats fixture))))
  ;; Face lookup
  (magit-ai-bench--record "tool-face/known"
    (lambda () (magit-ai--tool-face "claude-code")))
  (magit-ai-bench--record "tool-face/unknown"
    (lambda () (magit-ai--tool-face "unknown-tool")))
  ;; Name formatting
  (magit-ai-bench--record "format-tool-name/known"
    (lambda () (magit-ai--format-tool-name "claude-code")))
  (magit-ai-bench--record "format-tool-name/unknown"
    (lambda () (magit-ai--format-tool-name "some-new-tool")))
  ;; Propertize
  (magit-ai-bench--record "propertize-tool"
    (lambda () (magit-ai--propertize-tool "claude-code")))
  ;; Cache operations
  (let ((magit-ai--stats-cache (make-hash-table :test 'equal))
        (magit-ai-stats-cache-ttl 60)
        (default-directory "/test/"))
    (magit-ai-bench--record "cache-roundtrip"
      (lambda ()
        (magit-ai--cache-stats "HEAD" '(:ai-percent 42))
        (magit-ai--cached-stats "HEAD"))))
  ;; Blame parsing
  (when (fboundp 'magit-ai-blame--extract-tool)
    (magit-ai-bench--record "blame-extract/ai"
      (lambda () (magit-ai-blame--extract-tool "abc123 [claude-code] line")))
    (magit-ai-bench--record "blame-extract/human"
      (lambda () (magit-ai-blame--extract-tool "abc123 (John Doe 2024) line"))))
  (setq magit-ai-bench-results (nreverse magit-ai-bench-results))
  (message "")
  (message "Benchmarks complete."))

;; Main
(let* ((args (cl-remove "--" command-line-args-left :test #'equal))
       (mode (car args))
       (baseline-file ".benchmark-baseline"))
  (setq command-line-args-left nil)
  (magit-ai-bench--run-all)
  (pcase mode
    ("save"
     (with-temp-file baseline-file
       (prin1 magit-ai-bench-results (current-buffer))
       (insert "\n"))
     (message "Saved benchmark baseline to %s" baseline-file)
     (kill-emacs 0))
    ("check"
     (if (not (file-exists-p baseline-file))
         (progn
           (message "No benchmark baseline found.  Run 'make benchmark-baseline' first.")
           (message "Skipping benchmark regression check.")
           (kill-emacs 0))
       (let* ((baseline (with-temp-buffer
                          (insert-file-contents baseline-file)
                          (read (current-buffer))))
              (threshold 0.15)
              (regressions 0))
         (dolist (cur magit-ai-bench-results)
           (let* ((name (car cur))
                  (cur-time (cdr cur))
                  (base (assoc name baseline)))
             (when (and base (> (cdr base) 0))
               (let ((ratio (/ cur-time (cdr base))))
                 (when (> ratio (+ 1.0 threshold))
                   (message "REGRESSION: %s: %.4fs -> %.4fs (+%.1f%%)"
                            name (cdr base) cur-time
                            (* (- ratio 1.0) 100))
                   (cl-incf regressions))))))
         (if (> regressions 0)
             (progn
               (message "%d benchmark regression(s) exceed 15%% threshold" regressions)
               (kill-emacs 1))
           (message "No benchmark regressions (threshold: 15%%)")
           (kill-emacs 0)))))
    (_
     (kill-emacs 0))))

;;; benchmark.el ends here

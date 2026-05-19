;;; coverage.el --- Function-level coverage for magit-ai -*- lexical-binding: t; -*-

;;; Commentary:

;; Tracks which public magit-ai functions are exercised by the test suite.
;; Usage:
;;   emacs -Q --batch -L . -l scripts/coverage.el -- run
;;   emacs -Q --batch -L . -l scripts/coverage.el -- save
;;   emacs -Q --batch -L . -l scripts/coverage.el -- check

;;; Code:

(require 'cl-lib)

(defvar magit-ai-cov--called (make-hash-table :test 'equal)
  "Hash table tracking which functions were called.")

(defvar magit-ai-cov--functions nil
  "List of public function symbols being tracked.")

(defun magit-ai-cov--instrument ()
  "Add tracking advice to all public magit-ai functions."
  (setq magit-ai-cov--functions nil)
  (clrhash magit-ai-cov--called)
  (mapatoms
   (lambda (sym)
     (when (and (fboundp sym)
                (symbolp sym)
                (let ((name (symbol-name sym)))
                  (and (string-prefix-p "magit-ai-" name)
                       (not (string-match-p "--" name))
                       (not (string-suffix-p "-mode-map" name))
                       (not (string-suffix-p "-hook" name))
                       (not (string-suffix-p "-map" name)))))
       (push sym magit-ai-cov--functions)
       (let ((s sym))
         (advice-add s :before
                     (lambda (&rest _)
                       (puthash (symbol-name s) t magit-ai-cov--called))))))))

(defun magit-ai-cov--report ()
  "Report coverage results.  Return coverage percentage."
  (let ((total (length magit-ai-cov--functions))
        (covered 0)
        (uncovered nil))
    (dolist (sym magit-ai-cov--functions)
      (if (gethash (symbol-name sym) magit-ai-cov--called)
          (cl-incf covered)
        (push sym uncovered)))
    (let ((pct (if (> total 0) (* 100.0 (/ (float covered) total)) 100.0)))
      (message "")
      (message "Function coverage: %d/%d public functions (%.1f%%)"
               covered total pct)
      (when uncovered
        (message "Uncovered:")
        (dolist (sym (sort uncovered
                          (lambda (a b)
                            (string< (symbol-name a) (symbol-name b)))))
          (message "  %s" sym)))
      pct)))

;; Main
(let* ((args (cl-remove "--" command-line-args-left :test #'equal))
       (mode (car args))
       (baseline-file ".coverage-baseline"))
  (setq command-line-args-left nil)

  ;; Load all modules
  (require 'magit-ai-process)
  (require 'magit-ai nil t)
  (require 'magit-ai-sections nil t)
  (require 'magit-ai-blame nil t)
  (require 'magit-ai-diff nil t)
  (require 'magit-ai-log nil t)

  ;; Instrument before loading tests
  (magit-ai-cov--instrument)

  ;; Run tests
  (require 'ert)
  (load-file "test/magit-ai-tests.el")
  (ert-run-tests-batch)

  ;; Report
  (let ((pct (magit-ai-cov--report)))
    (pcase mode
      ("save"
       (with-temp-file baseline-file
         (insert (format "%.1f\n" pct)))
       (message "Saved coverage baseline: %.1f%%" pct)
       (kill-emacs 0))
      ("check"
       (if (not (file-exists-p baseline-file))
           (progn
             (message "No coverage baseline.  Run 'make coverage-baseline' to create one.")
             (message "Skipping coverage regression check.")
             (kill-emacs 0))
         (let ((baseline (with-temp-buffer
                           (insert-file-contents baseline-file)
                           (string-to-number (buffer-string)))))
           (if (< pct baseline)
               (progn
                 (message "COVERAGE REGRESSION: %.1f%% -> %.1f%%" baseline pct)
                 (kill-emacs 1))
             (message "Coverage OK: %.1f%% (baseline: %.1f%%)" pct baseline)
             (kill-emacs 0)))))
      (_
       (kill-emacs 0)))))

;;; coverage.el ends here

;;; run-checkdoc.el --- Run checkdoc in batch mode -*- lexical-binding: t; -*-

;;; Commentary:

;; Runs checkdoc on specified files and exits non-zero on errors.
;; Usage: emacs -Q --batch -L . -l scripts/run-checkdoc.el -- file1.el file2.el

;;; Code:

(require 'cl-lib)
(require 'checkdoc)

(defvar run-checkdoc--warnings nil
  "Accumulated checkdoc warnings.")

;; Capture warnings emitted by checkdoc-file via display-warning.
(advice-add #'display-warning :before
            (lambda (_type message &rest _args)
              (push message run-checkdoc--warnings)))

(let ((errors 0)
      (files (cl-remove "--" command-line-args-left :test #'equal)))
  (setq command-line-args-left nil)
  (dolist (file files)
    (setq run-checkdoc--warnings nil)
    (checkdoc-file file)
    (if run-checkdoc--warnings
        (progn
          (dolist (w (nreverse run-checkdoc--warnings))
            (message "checkdoc: %s: %s" file w))
          (setq errors (1+ errors)))
      (message "checkdoc: %s: ok" file)))
  (if (> errors 0)
      (progn
        (message "checkdoc: %d file(s) have issues" errors)
        (kill-emacs 1))
    (message "checkdoc: all files pass")
    (kill-emacs 0)))

;;; run-checkdoc.el ends here

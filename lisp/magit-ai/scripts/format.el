;;; format.el --- Format Emacs Lisp files -*- lexical-binding: t; -*-

;;; Commentary:

;; Formats Emacs Lisp files using standard Emacs indentation.
;; Usage: emacs -Q --batch -L . -l scripts/format.el -- file1.el file2.el

;;; Code:

(require 'cl-lib)

;; Ensure spaces, not tabs
(setq-default indent-tabs-mode nil)

;; Load packages for their indentation specs (ignore if unavailable).
(require 'transient nil t)
(require 'magit-process nil t)
(require 'magit-section nil t)

;; Fallback indent specs for when packages aren't available.
(dolist (spec '((transient-define-prefix . defun)
               (transient-define-suffix . defun)
               (transient-define-infix  . defun)
               (magit-insert-section    . 1)
               (magit-insert-heading    . defun)
               (magit--with-refresh-cache . 1)
               (magit--with-temp-process-buffer . 0)
               (defclass . defun)))
  (unless (get (car spec) 'lisp-indent-function)
    (put (car spec) 'lisp-indent-function (cdr spec))))

;; Project macros (from source declare forms).
(dolist (spec '((magit-ai--with-check          . 0)
               (magit-ai-wash                  . 1)
               (magit-ai--when-available       . 1)
               (magit-ai-with-mock-executable  . 0)
               (magit-ai-with-mock-unavailable . 0)
               (magit-ai-with-mock-output      . 1)
               (magit-ai-with-mock-json        . 1)))
  (put (car spec) 'lisp-indent-function (cdr spec)))

(let ((files (cl-remove "--" command-line-args-left :test #'equal)))
  (setq command-line-args-left nil)
  (dolist (file files)
    (find-file file)
    (emacs-lisp-mode)
    (indent-region (point-min) (point-max))
    (delete-trailing-whitespace)
    (save-buffer)
    (message "Formatted %s" file)
    (kill-buffer)))

(kill-emacs 0)

;;; format.el ends here

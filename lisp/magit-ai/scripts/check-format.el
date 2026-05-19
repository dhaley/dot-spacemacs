;;; check-format.el --- Check Emacs Lisp formatting -*- lexical-binding: t; -*-

;;; Commentary:

;; Checks that all specified Emacs Lisp files have correct indentation.
;; Usage: emacs -Q --batch -L . -l scripts/check-format.el -- file1.el file2.el

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

(defvar check-format--errors 0
  "Number of files with formatting errors.")

(defun check-format--file (file)
  "Check formatting of FILE.  Return non-nil if errors found."
  (with-temp-buffer
    (insert-file-contents file)
    (emacs-lisp-mode)
    (let ((original (buffer-string)))
      (indent-region (point-min) (point-max))
      (let ((formatted (buffer-string)))
        (unless (string= original formatted)
          (message "Formatting error in %s" file)
          (let ((i 0)
                (len (min (length original) (length formatted))))
            (while (and (< i len)
                        (= (aref original i) (aref formatted i)))
              (setq i (1+ i)))
            (message "  First difference at line %d"
                     (1+ (cl-count ?\n (substring original 0 i)))))
          t)))))

(let ((files (cl-remove "--" command-line-args-left :test #'equal)))
  (setq command-line-args-left nil)
  (dolist (file files)
    (when (check-format--file file)
      (setq check-format--errors (1+ check-format--errors))))
  (if (> check-format--errors 0)
      (progn
        (message "%d file(s) have formatting errors.  Run 'make format' to fix."
                 check-format--errors)
        (kill-emacs 1))
    (message "All files correctly formatted.")
    (kill-emacs 0)))

;;; check-format.el ends here

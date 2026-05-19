;;; magit-ai.el --- Git-ai integration for Magit  -*- lexical-binding:t -*-

;; Copyright (C) 2024-2026 The Magit Project Contributors

;; Author: John Wiegley <jwiegley@gmail.com>
;; Maintainer: John Wiegley <jwiegley@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (magit "4.0.0") (transient "0.5.0"))
;; URL: https://github.com/jwiegley/magit-ai
;; Keywords: git tools vc

;; SPDX-License-Identifier: BSD-3-Clause

;; See LICENSE.md for terms.  BSD-3-Clause.

;;; Commentary:

;; This library provides the main entry point for git-ai integration
;; in Magit.  Git-ai is a Rust tool that tracks AI-generated code in
;; Git repositories by attaching line-level authorship metadata via
;; git notes.
;;
;; Features provided:
;; - Transient menu for git-ai commands (accessible via `A' in magit-mode)
;; - AI blame mode showing which AI tool or human authored each line
;; - AI stats section in status buffer
;; - AI annotations in diff views

;;; Code:

(require 'magit)
(require 'magit-ai-process)
(require 'transient)

(eval-when-compile (require 'cl-lib))

;;; Customization

(defcustom magit-ai-mode-map-prefix "`"
  "Prefix key for git-ai transient in `magit-mode-map'.
Set this to nil to disable automatic keybinding."
  :group 'magit-ai
  :type '(choice (string :tag "Prefix key")
                 (const :tag "Disabled" nil)))

;;; Transient Menu

;;;###autoload (autoload 'magit-ai "magit-ai" nil t)
(transient-define-prefix magit-ai ()
  "Git-ai commands for AI authorship tracking."
  :man-page "git-ai"
  ["Arguments"
   ("-j" "JSON output" "--json")]
  ["Blame"
   ("b" "AI blame file" magit-ai-blame-file)
   ("B" "AI blame current" magit-ai-blame-buffer)]
  ["Statistics"
   ("s" "Show stats" magit-ai-show-stats)
   ("S" "Show stats at point" magit-ai-show-stats-at-point)]
  ["Diff"
   ("d" "AI diff" magit-ai-show-diff)]
  ["Other"
   ("p" "Show prompt" magit-ai-show-prompt)
   ("w" "Working log status" magit-ai-working-status)
   ("v" "Version" magit-ai-show-version)])

(defun magit-ai-arguments ()
  "Return current git-ai transient arguments."
  (transient-args 'magit-ai))

;;; Availability Check

(defmacro magit-ai--with-check (&rest body)
  "Execute BODY if git-ai is available, else show message."
  (declare (indent 0) (debug body))
  `(if (magit-ai-available-p)
       (progn ,@body)
     (message "Git-ai binary not found. Install from: https://github.com/jwiegley/git-ai")))

;;; Commands

;;;###autoload
(defun magit-ai-blame-file (file)
  "Run git-ai blame on FILE."
  (interactive (list (magit-read-file-from-rev "HEAD" "Blame file")))
  (magit-ai--with-check
    (let ((output (magit-ai-output "blame" file)))
      (if (string-empty-p output)
          (message "No AI authorship data for %s" file)
        (with-current-buffer (get-buffer-create "*magit-ai-blame*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert output)
            (goto-char (point-min)))
          (special-mode)
          (setq buffer-read-only t)
          (pop-to-buffer (current-buffer)))))))

;;;###autoload
(defun magit-ai-blame-buffer ()
  "Run git-ai blame on the current buffer's file."
  (interactive)
  (if-let ((file (magit-file-relative-name)))
      (magit-ai-blame-file file)
    (user-error "Buffer is not visiting a file in a Git repository")))

;;;###autoload
(defun magit-ai-show-stats (&optional rev)
  "Show AI authorship statistics for REV (default HEAD)."
  (interactive (list (magit-read-branch-or-commit "Stats for")))
  (magit-ai--with-check
    (let ((stats (magit-ai-stats (or rev "HEAD"))))
      (if stats
          (message "AI: %.1f%% (%d lines), Human: %.1f%% (%d lines), Total: %d"
                   (plist-get stats :ai-percent)
                   (plist-get stats :ai-additions)
                   (plist-get stats :human-percent)
                   (plist-get stats :human-additions)
                   (plist-get stats :total-additions))
        (message "No AI authorship data for %s" (or rev "HEAD"))))))

;;;###autoload
(defun magit-ai-show-stats-at-point ()
  "Show AI authorship statistics for commit at point."
  (interactive)
  (if-let ((commit (magit-commit-at-point)))
      (magit-ai-show-stats commit)
    (user-error "No commit at point")))

;;;###autoload
(defun magit-ai-show-diff (&optional rev)
  "Show AI-annotated diff for REV."
  (interactive (list (magit-read-branch-or-commit "Diff for")))
  (magit-ai--with-check
    (let ((output (magit-ai-output "diff" (or rev "HEAD"))))
      (if (string-empty-p output)
          (message "No diff data for %s" (or rev "HEAD"))
        (with-current-buffer (get-buffer-create "*magit-ai-diff*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert output)
            (goto-char (point-min))
            (ansi-color-apply-on-region (point-min) (point-max)))
          (diff-mode)
          (setq buffer-read-only t)
          (pop-to-buffer (current-buffer)))))))

;;;###autoload
(defun magit-ai-show-prompt (prompt-id)
  "Display the AI prompt with PROMPT-ID."
  (interactive "sPrompt ID: ")
  (magit-ai--with-check
    (let ((output (magit-ai-output "show-prompt" prompt-id)))
      (if (string-empty-p output)
          (message "Prompt %s not found" prompt-id)
        (with-current-buffer (get-buffer-create "*magit-ai-prompt*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert output)
            (goto-char (point-min)))
          (special-mode)
          (setq buffer-read-only t)
          (pop-to-buffer (current-buffer)))))))

;;;###autoload
(defun magit-ai-working-status ()
  "Show git-ai working log status."
  (interactive)
  (magit-ai--with-check
    (let ((output (magit-ai-output "status")))
      (if (string-empty-p output)
          (message "No uncommitted AI authorship data")
        (with-current-buffer (get-buffer-create "*magit-ai-status*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert output)
            (goto-char (point-min)))
          (special-mode)
          (setq buffer-read-only t)
          (pop-to-buffer (current-buffer)))))))

;;;###autoload
(defun magit-ai-show-version ()
  "Show git-ai version."
  (interactive)
  (if-let ((version (magit-ai-version)))
      (message "git-ai %s" version)
    (message "git-ai is not installed")))

;;; Keybinding Integration

(defun magit-ai--setup-keybinding ()
  "Set up keybinding for `magit-ai' in `magit-mode-map'."
  (when (and magit-ai-mode-map-prefix
             (boundp 'magit-mode-map))
    (define-key magit-mode-map
                (kbd magit-ai-mode-map-prefix) #'magit-ai)))

;; Set up keybinding when this file is loaded
(with-eval-after-load 'magit
  (magit-ai--setup-keybinding))

(provide 'magit-ai)
;;; magit-ai.el ends here

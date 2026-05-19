;;; magit-ai-log.el --- AI log integration for Magit  -*- lexical-binding:t -*-

;; Copyright (C) 2024-2026 The Magit Project Contributors

;; Author: John Wiegley <jwiegley@gmail.com>
;; Maintainer: John Wiegley <jwiegley@gmail.com>

;; SPDX-License-Identifier: BSD-3-Clause

;; See LICENSE.md for terms.  BSD-3-Clause.

;;; Commentary:

;; This library integrates AI authorship information into Magit log
;; buffers, showing AI percentage for each commit and optionally
;; highlighting commits with AI authorship.

;;; Code:

(require 'magit-log)
(require 'magit-ai-process)

(eval-when-compile (require 'cl-lib))

;;; Customization

(defcustom magit-ai-log-show-percentage t
  "Whether to show AI percentage in log margin.
When non-nil, the log margin displays the percentage of AI-authored
lines for each commit."
  :group 'magit-ai-display
  :type 'boolean)

(defcustom magit-ai-log-highlight-ai-commits t
  "Whether to highlight commits with AI authorship.
When non-nil, commits containing AI-authored code are highlighted
with `magit-ai-log-ai-commit' face."
  :group 'magit-ai-display
  :type 'boolean)

(defcustom magit-ai-log-percentage-threshold 10
  "Minimum AI percentage to highlight a commit.
Commits with AI percentage below this value are not highlighted
even when `magit-ai-log-highlight-ai-commits' is non-nil."
  :group 'magit-ai-display
  :type 'integer)

;;; Faces

(defface magit-ai-log-ai-commit
  '((((class color) (background light))
     :background "#F3E8FF")
    (((class color) (background dark))
     :background "#2D1B4E"))
  "Face for highlighting commits with AI authorship in logs."
  :group 'magit-faces)

(defface magit-ai-log-percentage
  '((((class color) (background light))
     :foreground "#6B4C9A")
    (((class color) (background dark))
     :foreground "#A78BFA"))
  "Face for AI percentage in log margin."
  :group 'magit-faces)

;;; Mode Variables

(defvar-local magit-ai-log-stats-cache nil
  "Cache of AI stats for commits in current log buffer.
An alist mapping commit hashes to stats plists.")

;;; Minor Mode

;;;###autoload
(define-minor-mode magit-ai-log-mode
  "Display AI authorship information in Magit log buffers."
  :lighter " AI-Log"
  :group 'magit-ai
  (if magit-ai-log-mode
      (magit-ai-log--enable)
    (magit-ai-log--disable)))

(defun magit-ai-log--enable ()
  "Enable AI log annotations."
  (unless (magit-ai-available-p)
    (setq magit-ai-log-mode nil)
    (user-error "Git-ai is not available"))
  (magit-ai-log--annotate))

(defun magit-ai-log--disable ()
  "Disable AI log annotations."
  (setq magit-ai-log-stats-cache nil))

;;; Annotation Functions

(defun magit-ai-log--annotate ()
  "Annotate commits in the current log buffer with AI stats."
  (setq magit-ai-log-stats-cache nil)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when-let* ((section (magit-current-section))
                  (type (and section (oref section type))))
        (when (eq type 'commit)
          (let ((rev (oref section value)))
            (magit-ai-log--annotate-commit section rev))))
      (magit-section-forward))))

(defun magit-ai-log--annotate-commit (section rev)
  "Annotate commit SECTION for REV with AI stats."
  (when-let ((stats (magit-ai-log--get-stats rev)))
    (push (cons rev stats) magit-ai-log-stats-cache)
    (let ((ai-pct (plist-get stats :ai-percent)))
      ;; Add percentage to margin
      (when (and magit-ai-log-show-percentage
                 (> ai-pct 0))
        (magit-ai-log--add-margin-annotation section ai-pct))
      ;; Highlight commit if significant AI content
      (when (and magit-ai-log-highlight-ai-commits
                 (>= ai-pct magit-ai-log-percentage-threshold))
        (magit-ai-log--highlight-commit section)))))

(defun magit-ai-log--get-stats (rev)
  "Get AI stats for REV, using cache if available."
  (or (alist-get rev magit-ai-log-stats-cache nil nil #'equal)
      (magit-ai-stats rev)))

(defun magit-ai-log--add-margin-annotation (section percentage)
  "Add AI PERCENTAGE to the margin of SECTION."
  (let ((start (oref section start))
        (inhibit-read-only t))
    (save-excursion
      (goto-char start)
      (let ((ov (make-overlay start (line-end-position))))
        (overlay-put ov 'magit-ai-log t)
        (overlay-put ov 'before-string
                     (propertize
                      (format " %3.0f%% " percentage)
                      'font-lock-face 'magit-ai-log-percentage
                      'display '((margin right-margin)
                                 ,(propertize
                                   (format "%3.0f%%" percentage)
                                   'font-lock-face 'magit-ai-log-percentage))))))))

(defun magit-ai-log--highlight-commit (section)
  "Apply highlighting to commit SECTION."
  (let ((start (oref section start))
        (end (oref section end))
        (inhibit-read-only t))
    (let ((ov (make-overlay start end)))
      (overlay-put ov 'magit-ai-log-highlight t)
      (overlay-put ov 'face 'magit-ai-log-ai-commit)
      (overlay-put ov 'priority -50))))

;;; Integration Hooks

(defun magit-ai-log--maybe-enable ()
  "Enable AI log mode if appropriate options are set."
  (when (and (or magit-ai-log-show-percentage
                 magit-ai-log-highlight-ai-commits)
             (magit-ai-available-p)
             (derived-mode-p 'magit-log-mode))
    (magit-ai-log-mode 1)))

;; Hook into magit-log-mode
(add-hook 'magit-log-mode-hook #'magit-ai-log--maybe-enable)

;;; Commands

;;;###autoload
(defun magit-ai-log-toggle ()
  "Toggle AI annotations in the current log buffer."
  (interactive)
  (if magit-ai-log-mode
      (magit-ai-log-mode -1)
    (magit-ai-log-mode 1)))

;;;###autoload
(defun magit-ai-log-show-stats-at-point ()
  "Show detailed AI stats for commit at point."
  (interactive)
  (if-let ((rev (magit-commit-at-point)))
      (let ((stats (magit-ai-log--get-stats rev)))
        (if stats
            (message "Commit %s: %.1f%% AI (%d lines), %.1f%% Human (%d lines)"
                     (magit-rev-abbrev rev)
                     (plist-get stats :ai-percent)
                     (plist-get stats :ai-additions)
                     (plist-get stats :human-percent)
                     (plist-get stats :human-additions))
          (message "No AI stats available for %s" (magit-rev-abbrev rev))))
    (user-error "No commit at point")))

(provide 'magit-ai-log)
;;; magit-ai-log.el ends here

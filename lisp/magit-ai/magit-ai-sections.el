;;; magit-ai-sections.el --- AI stats sections for Magit  -*- lexical-binding:t -*-

;; Copyright (C) 2024-2026 The Magit Project Contributors

;; Author: John Wiegley <jwiegley@gmail.com>
;; Maintainer: John Wiegley <jwiegley@gmail.com>

;; SPDX-License-Identifier: BSD-3-Clause

;; See LICENSE.md for terms.  BSD-3-Clause.

;;; Commentary:

;; This library provides status buffer sections for displaying AI
;; authorship statistics in Magit.

;;; Code:

(require 'magit)
(require 'magit-ai-process)

(eval-when-compile (require 'cl-lib))

;;; Section Class

(defclass magit-ai-stats-section (magit-section)
  ((stats :initform nil
          :initarg :stats
          :documentation "AI stats plist for this section.")))

;;; Customization

(defcustom magit-ai-stats-section-visibility 'hide
  "Initial visibility of the AI stats section.
If `show', the section is expanded by default.
If `hide', the section is collapsed by default."
  :group 'magit-ai-display
  :type '(choice (const :tag "Show" show)
                 (const :tag "Hide" hide)))

;;; Section Keymap

(defvar-keymap magit-ai-stats-section-map
  :doc "Keymap for `ai-stats' sections."
  "<remap> <magit-visit-thing>" #'magit-ai-stats-visit
  "<1>" (magit-menu-item "Show detailed stats" #'magit-ai-stats-visit))

(defun magit-ai-stats-visit ()
  "Show detailed AI stats for the current section."
  (interactive)
  (if-let* ((section (magit-current-section))
            (stats (and (magit-ai-stats-section-p section)
                        (oref section stats))))
      (magit-ai-show-stats "HEAD")
    (user-error "No AI stats at point")))

;;; Section Inserter

;;;###autoload
(defun magit-insert-ai-stats ()
  "Insert a section showing AI authorship statistics for HEAD.
This function is suitable for adding to `magit-status-sections-hook'
or `magit-status-headers-hook'."
  (when (and magit-ai-show-in-status
             (magit-ai-available-p)
             (magit-rev-verify "HEAD"))
    (magit--with-refresh-cache (list default-directory 'ai-stats "HEAD")
      (when-let ((stats (magit-ai-stats "HEAD")))
        (let ((ai-pct (plist-get stats :ai-percent))
              (human-pct (plist-get stats :human-percent))
              (total (plist-get stats :total-additions))
              (breakdown (plist-get stats :tool-breakdown)))
          (when (> total 0)
            (magit-insert-section section (ai-stats stats
                                                    (eq magit-ai-stats-section-visibility 'hide))
                                  (oset section stats stats)
                                  (magit-insert-heading
                                    (concat
                                     (propertize "AI Stats   " 'font-lock-face 'magit-section-heading)
                                     (propertize (format "%.0f%% AI" ai-pct)
                                                 'font-lock-face 'magit-ai-stats-ai-percent)
                                     ", "
                                     (propertize (format "%.0f%% Human" human-pct)
                                                 'font-lock-face 'magit-ai-stats-human-percent)
                                     (propertize (format " (%d lines)" total)
                                                 'font-lock-face 'magit-dimmed)))
                                  ;; Tool breakdown
                                  (when breakdown
                                    (magit-insert-section (ai-stats-breakdown)
                                      (dolist (tool-entry breakdown)
                                        (let* ((tool (symbol-name (car tool-entry)))
                                               (data (cdr tool-entry)))
                                          (when data
                                            (insert "  "
                                                    (magit-ai--propertize-tool tool)
                                                    ": "
                                                    (propertize
                                                     (format "%s lines"
                                                             (or (alist-get 'lines data)
                                                                 (alist-get 'additions data)
                                                                 "?"))
                                                     'font-lock-face 'magit-dimmed)
                                                    "\n")))))))))))))

;;; Header Inserter (alternative for compact display)

;;;###autoload
(defun magit-insert-ai-stats-header ()
  "Insert a header line showing AI authorship statistics.
This function is suitable for adding to `magit-status-headers-hook'."
  (when (and magit-ai-show-in-status
             (magit-ai-available-p)
             (magit-rev-verify "HEAD"))
    (magit--with-refresh-cache (list default-directory 'ai-stats-header "HEAD")
      (when-let ((stats (magit-ai-stats "HEAD")))
        (let ((ai-pct (plist-get stats :ai-percent))
              (human-pct (plist-get stats :human-percent))
              (total (plist-get stats :total-additions)))
          (when (> total 0)
            (magit-insert-section (ai-stats stats)
              (insert (propertize (format "%-10s" "AI: ")
                                  'font-lock-face 'magit-section-heading))
              (insert (propertize (format "%.0f%% AI" ai-pct)
                                  'font-lock-face 'magit-ai-stats-ai-percent))
              (insert ", ")
              (insert (propertize (format "%.0f%% Human" human-pct)
                                  'font-lock-face 'magit-ai-stats-human-percent))
              (insert (propertize (format " (%d lines)" total)
                                  'font-lock-face 'magit-dimmed))
              (insert ?\n))))))))

;;; Integration Helpers

;; Note: magit-ai-stats-section-p is auto-generated by defclass

;; Autoload declarations for section functions
(declare-function magit-ai-show-stats "magit-ai" (&optional rev))

(provide 'magit-ai-sections)
;;; magit-ai-sections.el ends here

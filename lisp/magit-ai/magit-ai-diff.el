;;; magit-ai-diff.el --- AI diff annotations for Magit  -*- lexical-binding:t -*-

;; Copyright (C) 2024-2026 The Magit Project Contributors

;; Author: John Wiegley <jwiegley@gmail.com>
;; Maintainer: John Wiegley <jwiegley@gmail.com>

;; SPDX-License-Identifier: BSD-3-Clause

;; See LICENSE.md for terms.  BSD-3-Clause.

;;; Commentary:

;; This library adds AI authorship annotations to Magit diff displays.
;; Added lines show which AI tool generated them using margin or fringe
;; indicators with distinct faces.

;;; Code:

(require 'magit-diff)
(require 'magit-ai-process)

(eval-when-compile (require 'cl-lib))

;;; Customization

(defcustom magit-ai-diff-annotation-style 'margin
  "Style for displaying AI annotations in diffs.
`margin' - Show tool name in left margin.
`fringe' - Show indicator in fringe.
`both' - Show both margin and fringe."
  :group 'magit-ai-display
  :type '(choice (const :tag "Margin" margin)
                 (const :tag "Fringe" fringe)
                 (const :tag "Both" both)))

(defcustom magit-ai-diff-margin-width 10
  "Width of the margin for AI annotations in diffs."
  :group 'magit-ai-display
  :type 'integer)

;;; Mode Variables

(defvar-local magit-ai-diff-overlays nil
  "List of AI diff annotation overlays.")

(defvar-local magit-ai-diff-data nil
  "AI diff annotation data for the current buffer.")

;;; Minor Mode

;;;###autoload
(define-minor-mode magit-ai-diff-mode
  "Display AI authorship annotations in Magit diff buffers."
  :lighter " AI-Diff"
  :group 'magit-ai
  (if magit-ai-diff-mode
      (magit-ai-diff--enable)
    (magit-ai-diff--disable)))

(defun magit-ai-diff--enable ()
  "Enable AI diff annotations."
  (unless (magit-ai-available-p)
    (setq magit-ai-diff-mode nil)
    (user-error "Git-ai is not available"))
  (magit-ai-diff--annotate))

(defun magit-ai-diff--disable ()
  "Disable AI diff annotations."
  (magit-ai-diff--remove-overlays)
  (setq magit-ai-diff-data nil))

;;; Annotation Functions

(defun magit-ai-diff--annotate ()
  "Fetch and apply AI annotations to the current diff buffer."
  (magit-ai-diff--remove-overlays)
  (when-let* ((rev (magit-ai-diff--get-revision))
              (data (magit-ai-diff--fetch-data rev)))
    (setq magit-ai-diff-data data)
    (magit-ai-diff--apply-annotations data)))

(defun magit-ai-diff--get-revision ()
  "Get the revision for the current diff buffer."
  (or magit-buffer-revision "HEAD"))

(defun magit-ai-diff--fetch-data (rev)
  "Fetch AI diff data for REV from git-ai."
  (condition-case nil
      (let ((output (magit-ai-output "diff" rev)))
        (unless (string-empty-p output)
          (magit-ai-diff--parse-output output)))
    (error nil)))

(defun magit-ai-diff--parse-output (output)
  "Parse git-ai diff OUTPUT into annotation data.
Returns an alist mapping file paths to line annotations."
  (let ((result nil)
        (current-file nil)
        (current-annotations nil))
    (dolist (line (split-string output "\n"))
      (cond
       ;; New file header
       ((string-match "^diff --git a/\\(.+\\) b/\\(.+\\)" line)
        (when (and current-file current-annotations)
          (push (cons current-file (nreverse current-annotations)) result))
        (setq current-file (match-string 2 line))
        (setq current-annotations nil))
       ;; Added line with AI annotation
       ((string-match "^\\+\\[\\([^]]+\\)\\]\\(.*\\)" line)
        (push (list :tool (match-string 1 line)
                    :content (match-string 2 line))
              current-annotations))
       ;; Added line without annotation (human)
       ((and (string-prefix-p "+" line)
             (not (string-prefix-p "+++" line)))
        (push (list :tool nil
                    :content (substring line 1))
              current-annotations))))
    ;; Don't forget last file
    (when (and current-file current-annotations)
      (push (cons current-file (nreverse current-annotations)) result))
    (nreverse result)))

(defun magit-ai-diff--apply-annotations (data)
  "Apply AI annotations from DATA to the current buffer."
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when-let* ((section (magit-current-section))
                  (type (oref section type)))
        (when (eq type 'hunk)
          (magit-ai-diff--annotate-hunk section data)))
      (magit-section-forward))))

(defun magit-ai-diff--annotate-hunk (section data)
  "Annotate hunk SECTION with AI data from DATA."
  (when-let* ((file (magit-ai-diff--section-file section))
              (file-data (alist-get file data nil nil #'equal)))
    (let ((start (oref section start))
          (end (oref section end)))
      (save-excursion
        (goto-char start)
        (while (< (point) end)
          (when (looking-at "^\\+[^+]")
            (let* ((line-content (buffer-substring-no-properties
                                  (1+ (point)) (line-end-position)))
                   (annotation (magit-ai-diff--find-annotation
                                line-content file-data)))
              (when annotation
                (magit-ai-diff--make-overlay
                 (point) (line-end-position)
                 (plist-get annotation :tool)))))
          (forward-line 1))))))

(defun magit-ai-diff--section-file (section)
  "Get the file path for diff SECTION."
  (when-let ((parent (oref section parent)))
    (when (memq (oref parent type) '(file hunk))
      (oref parent value))))

(defun magit-ai-diff--find-annotation (content file-data)
  "Find annotation for CONTENT in FILE-DATA."
  (cl-find-if (lambda (ann)
                (string-match-p (regexp-quote (plist-get ann :content))
                                content))
              file-data))

;;; Overlay Management

(defun magit-ai-diff--make-overlay (start end tool)
  "Create AI annotation overlay from START to END for TOOL."
  (let ((ov (make-overlay start end nil t nil)))
    (overlay-put ov 'magit-ai-diff t)
    (overlay-put ov 'magit-ai-tool tool)
    (cond
     ((memq magit-ai-diff-annotation-style '(margin both))
      (magit-ai-diff--apply-margin-overlay ov tool))
     ((memq magit-ai-diff-annotation-style '(fringe both))
      (magit-ai-diff--apply-fringe-overlay ov tool)))
    (push ov magit-ai-diff-overlays)))

(defun magit-ai-diff--apply-margin-overlay (ov tool)
  "Apply margin display to overlay OV for TOOL."
  (let* ((display-name (if tool
                           (magit-ai--format-tool-name tool)
                         "Human"))
         (face (if tool
                   (magit-ai--tool-face tool)
                 'magit-ai-author-human))
         (truncated (if (> (length display-name) magit-ai-diff-margin-width)
                        (substring display-name 0 (1- magit-ai-diff-margin-width))
                      display-name))
         (margin-string (propertize
                         (format (format "%%-%ds" magit-ai-diff-margin-width)
                                 truncated)
                         'font-lock-face face)))
    (overlay-put ov 'before-string
                 (propertize " " 'display
                             `((margin left-margin) ,margin-string)))))

(defun magit-ai-diff--apply-fringe-overlay (ov tool)
  "Apply fringe indicator to overlay OV for TOOL."
  (let ((face (if tool
                  (magit-ai--tool-face tool)
                'magit-ai-author-human)))
    (overlay-put ov 'line-prefix
                 (propertize " " 'display
                             `(left-fringe filled-rectangle ,face)))))

(defun magit-ai-diff--remove-overlays ()
  "Remove all AI diff annotation overlays."
  (dolist (ov magit-ai-diff-overlays)
    (delete-overlay ov))
  (setq magit-ai-diff-overlays nil))

;;; Integration Hooks

(defun magit-ai-diff--maybe-enable ()
  "Enable AI diff mode if `magit-ai-show-in-diff' is non-nil."
  (when (and magit-ai-show-in-diff
             (magit-ai-available-p)
             (derived-mode-p 'magit-diff-mode))
    (magit-ai-diff-mode 1)))

;; Hook into magit-diff-mode
(add-hook 'magit-diff-mode-hook #'magit-ai-diff--maybe-enable)

;;; Commands

;;;###autoload
(defun magit-ai-diff-toggle ()
  "Toggle AI annotations in the current diff buffer."
  (interactive)
  (if magit-ai-diff-mode
      (magit-ai-diff-mode -1)
    (magit-ai-diff-mode 1)))

;;;###autoload
(defun magit-ai-diff-refresh ()
  "Refresh AI annotations in the current diff buffer."
  (interactive)
  (when magit-ai-diff-mode
    (magit-ai-diff--annotate)))

(provide 'magit-ai-diff)
;;; magit-ai-diff.el ends here

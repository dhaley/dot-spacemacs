;;; magit-ai-blame.el --- AI blame integration for Magit  -*- lexical-binding:t -*-

;; Copyright (C) 2024-2026 The Magit Project Contributors

;; Author: John Wiegley <jwiegley@gmail.com>
;; Maintainer: John Wiegley <jwiegley@gmail.com>

;; SPDX-License-Identifier: BSD-3-Clause

;; See LICENSE.md for terms.  BSD-3-Clause.

;;; Commentary:

;; This library extends Magit's blame functionality to overlay AI
;; authorship information, showing which AI tool or human authored
;; each line using git-ai blame data.

;;; Code:

(require 'magit-blame)
(require 'magit-ai-process)

(eval-when-compile (require 'cl-lib))

;;; AI Blame Chunk Class

(defclass magit-ai-blame-chunk ()
  ((line-start :initarg :line-start
               :type integer
               :documentation "First line number of this chunk.")
   (line-end :initarg :line-end
             :type integer
             :documentation "Last line number of this chunk.")
   (tool :initarg :tool
         :initform nil
         :documentation "AI tool name, or nil for human-authored.")
   (author :initarg :author
           :initform nil
           :documentation "Human author name if not AI-authored.")
   (prompt-id :initarg :prompt-id
              :initform nil
              :documentation "AI prompt ID for this chunk."))
  "A chunk of AI blame information for a contiguous range of lines.")

;;; Customization

(defcustom magit-ai-blame-styles
  '((ai-headings
     (heading-format . "%A %16t %a\n"))
    (ai-margin
     (margin-format . " %t")
     (margin-width . 10)
     (margin-face . magit-blame-margin)))
  "Alist of AI blame styles.
Each element has the form (STYLE . SETTINGS), where STYLE is a
symbol and SETTINGS is an alist of style settings.

Format placeholders:
  %t - AI tool name or \"Human\"
  %a - Author name (human or AI tool)
  %A - Abbreviated tool name (3 chars)
  %p - Prompt ID"
  :group 'magit-ai-display
  :type '(alist :key-type symbol
                :value-type (alist :key-type symbol :value-type sexp)))

(defcustom magit-ai-blame-style 'ai-margin
  "Current AI blame display style.
Must be a key in `magit-ai-blame-styles'."
  :group 'magit-ai-display
  :type 'symbol)

;;; Mode Variables

(defvar-local magit-ai-blame-overlays nil
  "List of AI blame overlays in the current buffer.")

(defvar-local magit-ai-blame-chunks nil
  "List of AI blame chunks for the current buffer.")

(defvar-local magit-ai-blame-process nil
  "The git-ai blame process for the current buffer.")

;;; Minor Mode

;;;###autoload
(define-minor-mode magit-ai-blame-mode
  "Display AI authorship alongside git blame.
When enabled, shows which AI tool (or human) authored each line."
  :lighter " AI-Blame"
  :group 'magit-ai
  (if magit-ai-blame-mode
      (magit-ai-blame--enable)
    (magit-ai-blame--disable)))

(defun magit-ai-blame--enable ()
  "Enable AI blame mode, fetching and displaying AI blame data."
  (unless (magit-ai-available-p)
    (setq magit-ai-blame-mode nil)
    (user-error "Git-ai is not available"))
  (unless (magit-file-relative-name)
    (setq magit-ai-blame-mode nil)
    (user-error "Buffer is not visiting a file in a Git repository"))
  (magit-ai-blame--run))

(defun magit-ai-blame--disable ()
  "Disable AI blame mode, removing overlays."
  (magit-ai-blame--remove-overlays)
  (setq magit-ai-blame-chunks nil)
  (when magit-ai-blame-process
    (when (process-live-p magit-ai-blame-process)
      (kill-process magit-ai-blame-process))
    (setq magit-ai-blame-process nil)))

;;; Blame Process

(defun magit-ai-blame--run ()
  "Run git-ai blame asynchronously on the current buffer's file."
  (let* ((file (magit-file-relative-name))
         (buffer (current-buffer)))
    (magit-ai-blame--remove-overlays)
    (setq magit-ai-blame-chunks nil)
    (message "Running git-ai blame on %s..." file)
    (let ((output-buffer (generate-new-buffer " *magit-ai-blame-output*")))
      (setq magit-ai-blame-process
            (make-process
             :name "magit-ai-blame"
             :buffer output-buffer
             :command (list (magit-ai-executable-find) "blame" file)
             :sentinel (lambda (proc _event)
                         (when (eq (process-status proc) 'exit)
                           (let ((exit-code (process-exit-status proc)))
                             (if (zerop exit-code)
                                 (with-current-buffer buffer
                                   (when (buffer-live-p buffer)
                                     (magit-ai-blame--parse-output output-buffer)
                                     (magit-ai-blame--make-overlays)
                                     (message "AI blame complete")))
                               (message "git-ai blame failed with exit code %d" exit-code)))
                           (when (buffer-live-p output-buffer)
                             (kill-buffer output-buffer)))))))))

;;; Output Parsing

(defun magit-ai-blame--parse-output (output-buffer)
  "Parse git-ai blame output from OUTPUT-BUFFER.
Populates `magit-ai-blame-chunks' with parsed data."
  (setq magit-ai-blame-chunks nil)
  (with-current-buffer output-buffer
    (goto-char (point-min))
    ;; Parse the git-ai blame output format
    ;; Format: <commit> (<tool/author> <timestamp>) <line-content>
    ;; or standard git blame format with tool annotation
    (let ((line-num 1)
          current-chunk
          current-tool)
      (while (not (eobp))
        (let* ((line (buffer-substring-no-properties
                      (line-beginning-position) (line-end-position)))
               (tool (magit-ai-blame--extract-tool line)))
          ;; Group consecutive lines with same tool
          (if (equal tool current-tool)
              ;; Extend current chunk
              (when current-chunk
                (oset current-chunk line-end line-num))
            ;; Start new chunk
            (when current-chunk
              (push current-chunk magit-ai-blame-chunks))
            (setq current-chunk
                  (magit-ai-blame-chunk
                   :line-start line-num
                   :line-end line-num
                   :tool (and tool (not (equal tool "human")) tool)
                   :author (if (or (null tool) (equal tool "human"))
                               (magit-ai-blame--extract-author line)
                             tool)))
            (setq current-tool tool))
          (setq line-num (1+ line-num))
          (forward-line 1)))
      ;; Push final chunk
      (when current-chunk
        (push current-chunk magit-ai-blame-chunks))))
  (setq magit-ai-blame-chunks (nreverse magit-ai-blame-chunks)))

(defun magit-ai-blame--extract-tool (line)
  "Extract AI tool name from blame LINE.
Returns nil if human-authored, or a tool name string."
  ;; git-ai blame output shows tool in the author position
  ;; Format varies but typically shows AI tool name like "claude-code"
  (cond
   ((string-match "\\[\\(claude\\(?:-code\\)?\\)\\]" line)
    (match-string 1 line))
   ((string-match "\\[\\(cursor\\)\\]" line)
    (match-string 1 line))
   ((string-match "\\[\\(github-copilot\\|copilot\\)\\]" line)
    (match-string 1 line))
   ((string-match "\\[\\(gemini\\)\\]" line)
    (match-string 1 line))
   ((string-match "\\[\\(continue\\(?:-cli\\)?\\)\\]" line)
    (match-string 1 line))
   ((string-match "\\[AI:\\([^]]+\\)\\]" line)
    (match-string 1 line))
   ;; No AI marker - human authored
   (t nil)))

(defun magit-ai-blame--extract-author (line)
  "Extract human author name from blame LINE."
  ;; Standard git blame format: <hash> (<author> <date> <line-num>) content
  (when (string-match "(\\([^)]+\\))" line)
    (let ((info (match-string 1 line)))
      (when (string-match "^\\([^0-9]+\\)" info)
        (string-trim (match-string 1 info))))))

;;; Overlay Management

(defun magit-ai-blame--make-overlays ()
  "Create overlays for AI blame chunks."
  (magit-ai-blame--remove-overlays)
  (dolist (chunk magit-ai-blame-chunks)
    (let* ((start-line (oref chunk line-start))
           (end-line (oref chunk line-end))
           (start (save-excursion
                    (goto-char (point-min))
                    (forward-line (1- start-line))
                    (point)))
           (end (save-excursion
                  (goto-char (point-min))
                  (forward-line end-line)
                  (point))))
      (when (and (<= start (point-max))
                 (<= end (point-max)))
        (let ((ov (make-overlay start end nil t nil)))
          (magit-ai-blame--format-overlay ov chunk)
          (push ov magit-ai-blame-overlays))))))

(defun magit-ai-blame--format-overlay (overlay chunk)
  "Format OVERLAY for CHUNK according to current style."
  (let* ((style-settings (cdr (assq magit-ai-blame-style magit-ai-blame-styles)))
         (margin-format (alist-get 'margin-format style-settings))
         (margin-width (alist-get 'margin-width style-settings 10))
         (tool (oref chunk tool))
         (display-name (if tool
                           (magit-ai--format-tool-name tool)
                         "Human"))
         (face (if tool
                   (magit-ai--tool-face tool)
                 'magit-ai-author-human)))
    (overlay-put overlay 'magit-ai-blame-chunk chunk)
    (when margin-format
      ;; Set up margin display
      (let ((margin-string (magit-ai-blame--format-margin display-name margin-width face)))
        (overlay-put overlay 'before-string margin-string)))))

(defun magit-ai-blame--format-margin (tool-name width face)
  "Format margin string for TOOL-NAME with WIDTH using FACE."
  (let* ((truncated (if (> (length tool-name) width)
                        (substring tool-name 0 (- width 1))
                      tool-name))
         (padded (format (format "%%-%ds" width) truncated)))
    (propertize (concat " " padded " ")
                'font-lock-face face
                'display `((margin left-margin) ,(propertize padded 'font-lock-face face)))))

(defun magit-ai-blame--remove-overlays ()
  "Remove all AI blame overlays from the current buffer."
  (dolist (ov magit-ai-blame-overlays)
    (delete-overlay ov))
  (setq magit-ai-blame-overlays nil))

;;; Integration with magit-blame

(defun magit-ai-blame--maybe-enable ()
  "Enable AI blame if `magit-ai-show-in-blame' is non-nil."
  (when (and magit-ai-show-in-blame
             (magit-ai-available-p))
    (magit-ai-blame-mode 1)))

;; Hook into magit-blame-mode
(add-hook 'magit-blame-mode-hook #'magit-ai-blame--maybe-enable)

;;; Commands

;;;###autoload
(defun magit-ai-blame-toggle ()
  "Toggle AI blame overlay in the current buffer."
  (interactive)
  (if magit-ai-blame-mode
      (magit-ai-blame-mode -1)
    (magit-ai-blame-mode 1)))

;;;###autoload
(defun magit-ai-blame-chunk-at-point ()
  "Return the AI blame chunk at point, or nil."
  (let ((overlays (overlays-at (point))))
    (cl-loop for ov in overlays
             when (overlay-get ov 'magit-ai-blame-chunk)
             return (overlay-get ov 'magit-ai-blame-chunk))))

;;;###autoload
(defun magit-ai-blame-show-prompt-at-point ()
  "Show the AI prompt for the code at point."
  (interactive)
  (if-let* ((chunk (magit-ai-blame-chunk-at-point))
            (prompt-id (oref chunk prompt-id)))
      (magit-ai-show-prompt prompt-id)
    (user-error "No AI prompt information at point")))

;; Autoload declaration
(declare-function magit-ai-show-prompt "magit-ai" (prompt-id))

(provide 'magit-ai-blame)
;;; magit-ai-blame.el ends here

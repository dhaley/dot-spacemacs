;;; magit-ai-process.el --- Git-ai process management  -*- lexical-binding:t -*-

;; Copyright (C) 2024-2026 The Magit Project Contributors

;; Author: John Wiegley <jwiegley@gmail.com>
;; Maintainer: John Wiegley <jwiegley@gmail.com>

;; SPDX-License-Identifier: BSD-3-Clause

;; See LICENSE.md for terms.  BSD-3-Clause.

;;; Commentary:

;; This library implements process management for executing git-ai CLI
;; commands.  Git-ai is a Rust tool that tracks AI-generated code in Git
;; repositories by attaching line-level authorship metadata via git notes.
;;
;; The functions here follow Magit's established process patterns:
;; - Synchronous execution for output capture (magit-ai-string, magit-ai-lines)
;; - Synchronous execution for side-effects (magit-ai-call)
;; - Asynchronous execution (magit-ai-run-async)
;; - JSON output parsing for structured data

;;; Code:

(require 'magit-process)
(require 'json)

(eval-when-compile (require 'cl-lib))

;; Forward declarations for functions from other Magit modules
(declare-function magit-maybe-make-margin-overlay "magit-margin" ())
(declare-function magit-cancel-section "magit-section" ())

;;; Options

(defgroup magit-ai nil
  "Git-ai integration for Magit."
  :link '(info-link "(magit)Git-ai")
  :group 'magit)

(defgroup magit-ai-process nil
  "Git-ai process management."
  :group 'magit-ai)

(defcustom magit-ai-executable "git-ai"
  "The git-ai executable to use.
If this is not an absolute path, the executable is searched for in
the variable `exec-path'."
  :group 'magit-ai-process
  :type 'string)

(defcustom magit-ai-global-arguments nil
  "Global arguments to pass to git-ai commands.
These arguments are prepended to every git-ai invocation."
  :group 'magit-ai-process
  :type '(repeat string))

(defcustom magit-ai-environment nil
  "Environment variables for git-ai processes.
An alist of (VARIABLE . VALUE) pairs.  Set VARIABLE to VALUE in
the environment of git-ai processes.  Useful for setting
GIT_AI_DEBUG or other configuration."
  :group 'magit-ai-process
  :type '(alist :key-type string :value-type string))

;;; Display Options

(defgroup magit-ai-display nil
  "Options for displaying AI authorship information."
  :group 'magit-ai)

(defcustom magit-ai-show-in-blame t
  "Whether to show AI authorship overlay in `magit-blame'.
When non-nil, AI tool attribution is displayed alongside standard
git blame information."
  :group 'magit-ai-display
  :type 'boolean)

(defcustom magit-ai-show-in-diff t
  "Whether to show AI authorship annotations in diffs.
When non-nil, added lines in diffs display AI tool attribution
in the margin or fringe."
  :group 'magit-ai-display
  :type 'boolean)

(defcustom magit-ai-show-in-status t
  "Whether to show AI stats section in status buffer.
When non-nil, an AI authorship statistics section is displayed
in the Magit status buffer."
  :group 'magit-ai-display
  :type 'boolean)

(defcustom magit-ai-tool-face-alist
  '(("claude-code" . magit-ai-author-claude)
    ("claude" . magit-ai-author-claude)
    ("cursor" . magit-ai-author-cursor)
    ("github-copilot" . magit-ai-author-copilot)
    ("copilot" . magit-ai-author-copilot)
    ("gemini" . magit-ai-author-gemini)
    ("continue-cli" . magit-ai-author-continue)
    ("ai_tab" . magit-ai-author))
  "Alist mapping AI tool names to faces.
Each entry is (TOOL-NAME . FACE), where TOOL-NAME is a string
matching the tool identifier from git-ai, and FACE is the face
to use for displaying that tool's attribution."
  :group 'magit-ai-display
  :type '(alist :key-type string :value-type face))

(defcustom magit-ai-unknown-tool-face 'magit-ai-author
  "Face to use for unknown AI tools.
Used when an AI tool is not found in `magit-ai-tool-face-alist'."
  :group 'magit-ai-display
  :type 'face)

;;; Faces

(defface magit-ai-author
  '((t :inherit magit-blame-name))
  "Face for generic AI authorship attribution.
Used when the specific AI tool is unknown or when a general
AI indicator is needed."
  :group 'magit-faces)

(defface magit-ai-author-claude
  '((((class color) (background light))
     :foreground "#6B4C9A")
    (((class color) (background dark))
     :foreground "#A78BFA"))
  "Face for Claude-authored code.
Uses Anthropic brand colors (purple tones)."
  :group 'magit-faces)

(defface magit-ai-author-cursor
  '((((class color) (background light))
     :foreground "#0066CC")
    (((class color) (background dark))
     :foreground "#60A5FA"))
  "Face for Cursor-authored code.
Uses blue tones associated with Cursor branding."
  :group 'magit-faces)

(defface magit-ai-author-copilot
  '((((class color) (background light))
     :foreground "#238636")
    (((class color) (background dark))
     :foreground "#3FB950"))
  "Face for GitHub Copilot-authored code.
Uses GitHub green colors."
  :group 'magit-faces)

(defface magit-ai-author-gemini
  '((((class color) (background light))
     :foreground "#1A73E8")
    (((class color) (background dark))
     :foreground "#8AB4F8"))
  "Face for Google Gemini-authored code.
Uses Google blue colors."
  :group 'magit-faces)

(defface magit-ai-author-continue
  '((((class color) (background light))
     :foreground "#9333EA")
    (((class color) (background dark))
     :foreground "#C084FC"))
  "Face for Continue CLI-authored code.
Uses purple tones."
  :group 'magit-faces)

(defface magit-ai-author-human
  '((t :inherit magit-blame-name))
  "Face for human-authored code when displayed in AI context.
Used to distinguish human contributions when AI authorship
information is also being displayed."
  :group 'magit-faces)

(defface magit-ai-no-data
  '((t :inherit magit-dimmed))
  "Face for lines without AI authorship data.
Used when a line has no authorship tracking information available."
  :group 'magit-faces)

(defface magit-ai-stats-heading
  '((t :inherit magit-section-heading))
  "Face for AI stats section heading."
  :group 'magit-faces)

(defface magit-ai-stats-ai-percent
  '((((class color) (background light))
     :foreground "#6B4C9A"
     :weight bold)
    (((class color) (background dark))
     :foreground "#A78BFA"
     :weight bold))
  "Face for AI percentage in stats display."
  :group 'magit-faces)

(defface magit-ai-stats-human-percent
  '((((class color) (background light))
     :foreground "#166534"
     :weight bold)
    (((class color) (background dark))
     :foreground "#4ADE80"
     :weight bold))
  "Face for human percentage in stats display."
  :group 'magit-faces)

;;; Face Helper Functions

(defun magit-ai--tool-face (tool)
  "Return the face for AI TOOL.
Looks up TOOL in `magit-ai-tool-face-alist', falling back to
`magit-ai-unknown-tool-face' if not found."
  (or (cdr (assoc tool magit-ai-tool-face-alist))
      magit-ai-unknown-tool-face))

(defun magit-ai--format-tool-name (tool)
  "Format TOOL name for display.
Converts internal tool identifiers to user-friendly names."
  (pcase tool
    ("claude-code" "Claude")
    ("claude" "Claude")
    ("cursor" "Cursor")
    ("github-copilot" "Copilot")
    ("copilot" "Copilot")
    ("gemini" "Gemini")
    ("continue-cli" "Continue")
    ("ai_tab" "AI Tab")
    (_ (capitalize (replace-regexp-in-string "[-_]" " " tool)))))

(defun magit-ai--propertize-tool (tool)
  "Return TOOL propertized with its appropriate face."
  (propertize (magit-ai--format-tool-name tool)
              'face (magit-ai--tool-face tool)))

;;; Binary Discovery

(defvar magit-ai--executable-cache nil
  "Cached result of `magit-ai-executable-find'.")

(defun magit-ai-executable-find ()
  "Return the absolute path to the git-ai executable, or nil if not found.
The result is cached for the duration of the Emacs session."
  (or magit-ai--executable-cache
      (setq magit-ai--executable-cache
            (if (file-name-absolute-p magit-ai-executable)
                (and (file-executable-p magit-ai-executable)
                     magit-ai-executable)
              (executable-find magit-ai-executable t)))))

(defun magit-ai-available-p ()
  "Return non-nil if git-ai is available."
  (and (magit-ai-executable-find) t))

(defun magit-ai--assert-available ()
  "Signal an error if git-ai is not available."
  (unless (magit-ai-available-p)
    (user-error "Cannot find git-ai executable; please install it or set `magit-ai-executable'")))

;;; Environment

(defun magit-ai-process-environment ()
  "Return the process environment for git-ai commands.
This includes the current `process-environment' plus any variables
specified in `magit-ai-environment'."
  (append (mapcar (lambda (pair)
                    (concat (car pair) "=" (cdr pair)))
                  magit-ai-environment)
          process-environment))

;;; Argument Processing

(defun magit-ai-process-arguments (args)
  "Prepare ARGS for git-ai invocation.
Flatten ARGS and prepend `magit-ai-global-arguments'."
  (append magit-ai-global-arguments (flatten-tree args)))

;;; Synchronous Execution

(defun magit-ai-process-file (&optional infile buffer display &rest args)
  "Execute git-ai synchronously, returning its exit code.
INFILE, BUFFER, and DISPLAY have the same meaning as in `process-file'.
ARGS are passed to git-ai after processing with `magit-ai-process-arguments'."
  (magit-ai--assert-available)
  (let ((process-environment (magit-ai-process-environment))
        (default-process-coding-system (magit--process-coding-system)))
    (apply #'process-file
           (magit-ai-executable-find)
           infile buffer display
           (magit-ai-process-arguments args))))

(defun magit-ai-call (&rest args)
  "Execute git-ai with ARGS synchronously for side-effects.
Return the exit code.  Output is logged to the process buffer."
  (magit-ai--assert-available)
  (let* ((process-environment (magit-ai-process-environment))
         (default-process-coding-system (magit--process-coding-system))
         (flat-args (magit-ai-process-arguments args)))
    (pcase-let ((`(,process-buf . ,section)
                 (magit-process-setup (magit-ai-executable-find) flat-args)))
      (magit-process-finish
       (magit-ai-process-file nil process-buf nil args)
       process-buf nil default-directory section))))

(defun magit-ai-exit-code (&rest args)
  "Execute git-ai with ARGS, returning its exit code."
  (magit-ai--assert-available)
  (magit-ai-process-file nil nil nil args))

(defun magit-ai-success (&rest args)
  "Execute git-ai with ARGS, returning t if exit code is 0."
  (= (magit-ai-exit-code args) 0))

(defun magit-ai-insert (&rest args)
  "Execute git-ai with ARGS, insert output at point, return exit code."
  (magit-ai--assert-available)
  (magit-ai-process-file nil (list t nil) nil args))

(defun magit-ai-string (&rest args)
  "Execute git-ai with ARGS, returning the first line of output.
Return nil if the exit code is non-zero or there is no output."
  (setq args (flatten-tree args))
  (magit--with-refresh-cache (cons default-directory (cons 'git-ai args))
    (magit--with-temp-process-buffer
      (and (zerop (apply #'magit-ai-insert args))
           (not (bobp))
           (progn
             (goto-char (point-min))
             (buffer-substring-no-properties (point) (line-end-position)))))))

(defun magit-ai-output (&rest args)
  "Execute git-ai with ARGS, returning all output as a string."
  (setq args (flatten-tree args))
  (magit--with-refresh-cache (cons default-directory (cons 'git-ai args))
    (magit--with-temp-process-buffer
      (magit-ai-insert args)
      (buffer-substring-no-properties (point-min) (point-max)))))

(defun magit-ai-lines (&rest args)
  "Execute git-ai with ARGS, returning output as a list of lines.
Empty lines are omitted."
  (magit--with-temp-process-buffer
    (apply #'magit-ai-insert args)
    (split-string (buffer-string) "\n" t)))

;;; JSON Parsing

(defun magit-ai-json (&rest args)
  "Execute git-ai with ARGS, parsing output as JSON.
Return the parsed JSON as an alist, or nil on error."
  (when-let ((output (magit-ai-output args)))
    (condition-case nil
        (json-parse-string output :object-type 'alist)
      (json-parse-error nil))))

(defun magit-ai--parse-stats (json)
  "Parse git-ai stats JSON output.
JSON should be the result of `magit-ai-json' for a stats command.
Returns a plist with:
  :ai-percent - percentage of AI-authored lines
  :human-percent - percentage of human-authored lines
  :ai-additions - number of AI-added lines
  :human-additions - number of human-added lines
  :total-additions - total added lines
  :tool-breakdown - alist of (tool . lines) for AI tools"
  (when json
    (let ((human (alist-get 'human_additions json 0))
          (ai (alist-get 'total_ai_additions json 0))
          (breakdown (alist-get 'tool_model_breakdown json)))
      (let ((total (+ human ai)))
        (list :ai-percent (if (zerop total) 0 (* 100.0 (/ (float ai) total)))
              :human-percent (if (zerop total) 100 (* 100.0 (/ (float human) total)))
              :ai-additions ai
              :human-additions human
              :total-additions total
              :tool-breakdown breakdown)))))

(defun magit-ai-stats (&optional rev)
  "Get AI authorship statistics for REV (default HEAD).
Returns a plist as described in `magit-ai--parse-stats', or nil if
git-ai is unavailable or the command fails."
  (when (magit-ai-available-p)
    (magit-ai--parse-stats
     (magit-ai-json "stats" "--json" (or rev "HEAD")))))

;;; Asynchronous Execution

(defvar magit-ai-this-process nil
  "The currently running asynchronous git-ai process.")

(defun magit-ai-run-async (&rest args)
  "Start git-ai asynchronously with ARGS.
Return the process object.  The process buffer is set up following
Magit's conventions."
  (magit-ai--assert-available)
  (magit-msg "Running git-ai %s" (string-join (flatten-tree args) " "))
  (let* ((process-environment (magit-ai-process-environment))
         (default-process-coding-system (magit--process-coding-system))
         (flat-args (magit-ai-process-arguments args)))
    (pcase-let ((`(,process-buf . ,section)
                 (magit-process-setup (magit-ai-executable-find) flat-args)))
      (let* ((process-connection-type magit-process-connection-type)
             (process (apply #'start-file-process
                             "git-ai"
                             process-buf
                             (magit-ai-executable-find)
                             flat-args)))
        (setq magit-ai-this-process process)
        (with-current-buffer process-buf
          (set-marker (process-mark process) (point)))
        (process-put process 'section section)
        (process-put process 'command-buf (current-buffer))
        (process-put process 'default-dir default-directory)
        (set-process-sentinel process #'magit-ai-process-sentinel)
        (set-process-filter process #'magit-process-filter)
        (magit-process-set-mode-line (magit-ai-executable-find) flat-args)
        process))))

(defun magit-ai-process-sentinel (process event)
  "Default sentinel for git-ai processes.
Handles PROCESS completion EVENT, updates the section, and optionally
refreshes Magit buffers."
  (let ((inhibit-quit t))
    (when (memq (process-status process) '(exit signal))
      (setq event (substring event 0 -1))
      (when (string-match "^finished" event)
        (message "git-ai %s" event))
      (magit-process-finish process)
      (when (eq process magit-ai-this-process)
        (setq magit-ai-this-process nil))
      (unless (process-get process 'inhibit-refresh)
        (magit-refresh))
      (magit-process-unset-mode-line default-directory))))

;;; Wash Functions

(defun magit-ai-wash (washer &rest args)
  "Execute git-ai with ARGS, inserting washed output at point.
Similar to `magit-git-wash', but for git-ai commands.  WASHER is
called with ARGS on the inserted output."
  (declare (indent 1))
  (setq args (flatten-tree args))
  (let ((beg (point))
        (exit (magit-ai-insert args)))
    (if (= (point) beg)
        (magit-cancel-section)
      (unless (bolp)
        (insert "\n"))
      (when (zerop exit)
        (save-restriction
          (narrow-to-region beg (point))
          (goto-char beg)
          (funcall washer args))
        (when (or (= (point) beg)
                  (= (point) (1+ beg)))
          (magit-cancel-section))
        (magit-maybe-make-margin-overlay)))
    exit))

;;; Error Handling

(defun magit-ai--handle-unavailable ()
  "Display a message when git-ai is not available.
Returns nil, allowing callers to gracefully degrade."
  (message "git-ai is not installed or not in PATH")
  nil)

(defun magit-ai-with-fallback (fallback &rest body)
  "Execute BODY if git-ai is available, otherwise return FALLBACK.
This macro provides graceful degradation when git-ai is unavailable."
  (declare (indent 1))
  (if (magit-ai-available-p)
      (eval (cons 'progn body))
    fallback))

;;; Version Checking

(defvar magit-ai--version-cache nil
  "Cached git-ai version string.")

(defun magit-ai-version ()
  "Return the git-ai version string, or nil if unavailable."
  (or magit-ai--version-cache
      (when (magit-ai-available-p)
        (setq magit-ai--version-cache
              (magit-ai-string "version")))))

;;; Performance Utilities

(defvar magit-ai--stats-cache (make-hash-table :test 'equal)
  "TTL-based cache for git-ai stats results.
Keys are (directory . revision), values are (timestamp . result).")

(defcustom magit-ai-stats-cache-ttl 30
  "Time-to-live in seconds for cached stats results.
Set to 0 to disable caching."
  :group 'magit-ai-process
  :type 'integer)

(defun magit-ai--cache-key (rev)
  "Return cache key for REV in current directory."
  (cons default-directory rev))

(defun magit-ai--cached-stats (rev)
  "Return cached stats for REV if still valid, nil otherwise."
  (when (> magit-ai-stats-cache-ttl 0)
    (let* ((key (magit-ai--cache-key rev))
           (entry (gethash key magit-ai--stats-cache)))
      (when entry
        (let ((timestamp (car entry))
              (result (cdr entry)))
          (if (< (- (float-time) timestamp) magit-ai-stats-cache-ttl)
              result
            ;; Expired, remove entry
            (remhash key magit-ai--stats-cache)
            nil))))))

(defun magit-ai--cache-stats (rev result)
  "Cache RESULT for REV in current directory."
  (when (and result (> magit-ai-stats-cache-ttl 0))
    (puthash (magit-ai--cache-key rev)
             (cons (float-time) result)
             magit-ai--stats-cache))
  result)

(defun magit-ai-stats-cached (&optional rev)
  "Get AI stats for REV with TTL caching.
Uses `magit-ai-stats-cache-ttl' to determine cache validity."
  (let ((rev (or rev "HEAD")))
    (or (magit-ai--cached-stats rev)
        (magit-ai--cache-stats rev (magit-ai-stats rev)))))

(defun magit-ai-clear-cache ()
  "Clear all cached git-ai data."
  (interactive)
  (clrhash magit-ai--stats-cache)
  (setq magit-ai--executable-cache nil)
  (setq magit-ai--version-cache nil)
  (message "Cleared magit-ai cache"))

;;; Benchmarking (for development)

(defun magit-ai--benchmark (fn &rest args)
  "Benchmark FN with ARGS, return (result . time-ms).
For development and performance testing."
  (let ((start (current-time)))
    (cons (apply fn args)
          (* 1000 (float-time (time-subtract (current-time) start))))))

(defun magit-ai-benchmark-stats (&optional rev)
  "Benchmark stats retrieval for REV.
Returns time in milliseconds."
  (interactive (list (magit-read-branch-or-commit "Benchmark stats for")))
  (let ((result (magit-ai--benchmark #'magit-ai-stats (or rev "HEAD"))))
    (message "Stats retrieval took %.2fms" (cdr result))
    (cdr result)))

(provide 'magit-ai-process)
;;; magit-ai-process.el ends here

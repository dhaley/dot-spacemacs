;;; cloudwatch-tail.el --- Tail AWS CloudWatch log groups in comint buffers -*- lexical-binding: t; -*-

;;; Commentary:
;; Provides named comint buffers for tailing CloudWatch log groups.
;; Each buffer gets a tinted background and keyword highlighting for
;; ERROR / Exception (red) and SUCCESS (green) lines.
;;
;; Usage:
;;   M-x cwt-launch          – pick a log alias from the list
;;   M-x cwt-launch-all      – open every alias at once
;;   M-x cwt-stop            – kill a running tail buffer
;;   M-x cwt-stop-all        – kill all tail buffers

;;; Code:

(require 'comint)
(require 'ansi-color)

;; ── log aliases ────────────────────────────────────────────────────
(defvar cwt-since "10m"
  "How far back to fetch logs on launch (e.g. \"1m\", \"5m\", \"1h\").")

(defvar cwt-log-aliases nil
  "Alist of (ALIAS . LOG-GROUP-OR-LIST).
Value is either a log group string, or a list of (LOG-GROUP &rest EXTRA-ARGS).")

(setq cwt-log-aliases
      '(("resourcetagger"   . "/aws/lambda/ops-scheduledtagging-lambda-function")
        ("qremove"          . "/aws/lambda/ops-scheduledtagging-delete-sqs-lambda")
        ("statefailure"     . "/aws/lambda/ops-scheduledtagging-log-failure-lambda")
        ("logbus"           . "/aws/events/ops-scheduledtagging-bus-cloudwatch-loggroup")
        ("cesearch"         . "/aws/lambda/ops-scheduledtagging-cetobus-lambda-function")
        ("qpush"            . "/aws/lambda/ops-scheduledtagging-populatesqs-lambda-function")
        ("unenhancedlogbus" . "/aws/events/ops-scheduledtagging-unenhancedbus-cloudwatch-loggroup")
        ("eventbridge_bus"  . "/aws/events/ops-scheduledtagging-eventbridge-bus")
        ("acesearch"        . ("/aws/lambda/ops-scheduledtagging-resources-to-acebus-lambda-function" "--since" "1m"))
        ("sandboxsearch"    . ("/aws/lambda/ops-scheduledtagging-resources-to-sandboxbus-lambda-function" "--since" "1m"))
        ("bus_search"       . "/aws/lambda/ops-scheduledtagging-resources-to-bus-lambda-function")
        ("loggroup_search"  . "/aws/lambda/ops-scheduledtagging-resources-to-loggroupbus-lambda-function")
        ("check_dlq"        . "/aws/lambda/ops-scheduledtagging-check-dlq")
        ("config_transform" . "/aws/lambda/ops-scheduledtagging-config-transform-lambda-function")
        ("corrections"      . "/aws/lambda/ops-scheduledtagging-corrections-to-bus-lambda-function")
        ("directclientlist" . "/aws/lambda/ops-scheduledtagging-search-directclientlist-lambda-function")
        ("dynamo_scanner"   . "/aws/lambda/ops-scheduledtagging-dynamo-scanner")
        ("expandarray"      . "/aws/lambda/ops-scheduledtagging-expandobjecttoarray-lambda-function")
        ("fetch"            . "/aws/lambda/ops-scheduledtagging-fetch-lambda")
        ("fetchaccounts"    . "/aws/lambda/ops-scheduledtagging-fetchaccounts-lambda-function")
        ("receive_sqs"      . "/aws/lambda/ops-scheduledtagging-receive-sqs-lambda")
        ("reprocess_dlq"    . "/aws/lambda/ops-scheduledtagging-reprocess-dlq")
        ("s3_policy_eval"   . "/aws/lambda/ops-scheduledtagging-s3-policy-evaluator")
        ("s3_policy_fix"    . "/aws/lambda/ops-scheduledtagging-s3-policy-remediation")
        ("error"            . ("/aws/lambda/ops-scheduledtagging-lambda-function" "--filter-pattern" "?ERROR ?Exception"))
        ("fail"             . ("/aws/lambda/ops-scheduledtagging-log-failure-lambda" "--filter-pattern" "TAGGING_FAILURE"))
        ("success"          . ("/aws/lambda/ops-scheduledtagging-lambda-function" "--filter-pattern" "Successfully tagged resource"))))

(defun cwt--build-cmd (alias)
  "Build the full aws logs tail command string for ALIAS."
  (let ((entry (cdr (assoc alias cwt-log-aliases))))
    (if (listp entry)
        (let* ((group (car entry))
               (extra (cdr entry))
               (has-since (member "--since" extra))
               (since-part (if has-since "" (format " --since '%s'" cwt-since)))
               (extra-str (mapconcat (lambda (s)
                                       (if (string-prefix-p "--" s) s
                                         (shell-quote-argument s)))
                                     extra " ")))
          (format "aws logs tail '%s' --follow%s %s" group since-part extra-str))
      (format "aws logs tail '%s' --follow --since '%s'" entry cwt-since))))

;; ── per-buffer background tints ────────────────────────────────────
;; Error-oriented aliases get reddish tints, success gets greenish,
;; everything else gets a subtle unique tint.
(defvar cwt--bg-colors-dark
  '(("error"          . "#2a1515")
    ("fail"           . "#2a1a15")
    ("statefailure"   . "#2a1818")
    ("success"        . "#152a15")
    ("resourcetagger" . "#15192a")
    ("tag.log1"       . "#1a1528")
    ("qremove"        . "#15252a")
    ("logbus"         . "#1a2015")
    ("cesearch"       . "#1f1525")
    ("qpush"          . "#151f2a")
    ("unenhancedlogbus" . "#201a15")
    ("acesearch"      . "#15201f")
    ("sandboxsearch"  . "#1a1a20")
    ("bus_search"     . "#1a1520")
    ("loggroup_search" . "#15201a")
    ("check_dlq"      . "#251518")
    ("config_transform" . "#181a25")
    ("corrections"    . "#1a2518")
    ("directclientlist" . "#201518")
    ("dynamo_scanner" . "#18251a")
    ("eventbridge_bus" . "#1a1825")
    ("expandarray"    . "#251a18")
    ("fetch"          . "#181525")
    ("fetchaccounts"  . "#25181a")
    ("receive_sqs"    . "#151a25")
    ("reprocess_dlq"  . "#251815")
    ("s3_policy_eval" . "#1a2520")
    ("s3_policy_fix"  . "#201a25"))
  "Per-alias background colors for dark themes.")

(defvar cwt--bg-colors-light
  '(("error"          . "#fff0f0")
    ("fail"           . "#fff5ee")
    ("statefailure"   . "#fff0f5")
    ("success"        . "#f0fff0")
    ("resourcetagger" . "#f0f0ff")
    ("tag.log1"       . "#f5f0ff")
    ("qremove"        . "#f0faff")
    ("logbus"         . "#f5fff0")
    ("cesearch"       . "#faf0ff")
    ("qpush"          . "#f0f5ff")
    ("unenhancedlogbus" . "#fff8f0")
    ("acesearch"      . "#f0fff8")
    ("sandboxsearch"  . "#f5f5ff")
    ("bus_search"     . "#f5f0fa")
    ("loggroup_search" . "#f0faf5")
    ("check_dlq"      . "#fff0f3")
    ("config_transform" . "#f3f5ff")
    ("corrections"    . "#f5fff3")
    ("directclientlist" . "#faf0f3")
    ("dynamo_scanner" . "#f3faf5")
    ("eventbridge_bus" . "#f5f3ff")
    ("expandarray"    . "#fff5f3")
    ("fetch"          . "#f3f0ff")
    ("fetchaccounts"  . "#fff3f5")
    ("receive_sqs"    . "#f0f5fa")
    ("reprocess_dlq"  . "#faf3f0")
    ("s3_policy_eval" . "#f5fff8")
    ("s3_policy_fix"  . "#f8f5ff"))
  "Per-alias background colors for light themes.")

(defun cwt--bg-for (alias)
  "Return background color for ALIAS, adapting to current theme."
  (let* ((light-p (eq (frame-parameter nil 'background-mode) 'light))
         (colors (if light-p cwt--bg-colors-light cwt--bg-colors-dark)))
    (or (cdr (assoc alias colors))
        (if light-p "#f8f8f8" "#1a1a1a"))))

;; ── font-lock faces ───────────────────────────────────────────────
(defface cwt-error-face
  '((((background dark))  :foreground "#ff6666" :weight bold)
    (((background light)) :foreground "#cc0000" :weight bold))
  "Face for ERROR / Exception lines.")

(defface cwt-warn-face
  '((((background dark))  :foreground "#ffaa44")
    (((background light)) :foreground "#996600"))
  "Face for WARNING lines.")

(defface cwt-success-face
  '((((background dark))  :foreground "#66ff88" :weight bold)
    (((background light)) :foreground "#007700" :weight bold))
  "Face for success lines.")

(defface cwt-timestamp-face
  '((((background dark))  :foreground "#888899")
    (((background light)) :foreground "#888888"))
  "Face for CloudWatch timestamps.")

(defvar cwt-font-lock-keywords
  '(("\\(ERROR\\|Exception\\|Traceback\\|TAGGING_FAILURE\\)" 0 'cwt-error-face t)
    ("\\(WARN\\|WARNING\\)" 0 'cwt-warn-face t)
    ("\\(Successfully tagged resource\\|SUCCESS\\)" 0 'cwt-success-face t)
    ("^[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9:+.-]+" 0 'cwt-timestamp-face t))
  "Font-lock keywords for CloudWatch tail buffers.")

;; ── UTC → local time conversion ───────────────────────────────────
(defvar cwt-timezone "America/Denver"
  "Timezone for converting CloudWatch UTC timestamps.")

(defun cwt--convert-utc-timestamps (_string)
  "Convert UTC ISO-8601 timestamps to local time in the last comint output.
Modeled after `ansi-color-process-output'."
  (let ((start-marker comint-last-output-start)
        (end-marker (process-mark (get-buffer-process (current-buffer)))))
    (save-excursion
      ;; Back up 35 chars before start-marker to catch timestamps split
      ;; across chunk boundaries (timestamp is ~33 chars)
      (goto-char (max (point-min) (- start-marker 35)))
      (while (re-search-forward
              "\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)T\\([0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}\\)\\(\\.[0-9]+\\)?\\+00:00"
              end-marker t)
        (let* ((date-str (match-string 1))
               (time-str (match-string 2))
               (frac (or (match-string 3) ""))
               (parsed (parse-time-string (concat date-str " " time-str)))
               (time (encode-time (nth 0 parsed) (nth 1 parsed) (nth 2 parsed)
                                  (nth 3 parsed) (nth 4 parsed) (nth 5 parsed)
                                  0))  ; UTC
               (local (format-time-string "%Y-%m-%dT%H:%M:%S" time cwt-timezone))
               (offset (format-time-string "%z" time cwt-timezone))
               ;; Format offset as -06:00 instead of -0600
               (tz-fmt (concat (substring offset 0 3) ":" (substring offset 3))))
          (replace-match (concat local frac tz-fmt) t t))))))

;; ── major mode ────────────────────────────────────────────────────
(define-derived-mode cwt-mode comint-mode "CW-Tail"
  "Major mode for tailing CloudWatch logs."
  (setq-local comint-process-echoes nil)
  (setq-local comint-scroll-to-bottom-on-output t)
  (ansi-color-for-comint-mode-on)
  (font-lock-add-keywords nil cwt-font-lock-keywords)
  (font-lock-mode 1)
  (setq buffer-read-only nil)
  (add-hook 'comint-output-filter-functions #'cwt--convert-utc-timestamps nil t))

;; ── commands ──────────────────────────────────────────────────────
(defun cwt--buffer-name (alias)
  "Return buffer name for ALIAS."
  (format "*cwt:%s*" alias))

(defvar cwt-process-environment
  `(,(concat "AWS_SHARED_CREDENTIALS_FILE=" (expand-file-name "~/shared_credentials_files/credentials.emacs"))
    ,(concat "AWS_CONFIG_FILE=" (expand-file-name "~/shared_credentials_files/.aws/config"))
    "AWS_PROFILE=default"
    "AWS_REGION=us-west-2"
    "AWS_ACCESS_KEY_ID="
    "AWS_SECRET_ACCESS_KEY="
    "AWS_SESSION_TOKEN="
    ,(concat "SSL_CERT_FILE=" (expand-file-name "~/.ssl/cacert.pem"))
    ,(concat "AWS_CA_BUNDLE=" (expand-file-name "~/.ssl/cacert.pem"))
    ,(concat "REQUESTS_CA_BUNDLE=" (expand-file-name "~/.ssl/cacert.pem")))
  "Extra env vars prepended to `process-environment' for cwt buffers.")

(defun cwt--refresh-creds ()
  "Refresh AWS credentials via the emacs-aws-refresh script."
  (interactive)
  (message "Refreshing AWS credentials...")
  (shell-command "/usr/local/bin/emacs-aws-refresh")
  (message "AWS credentials refreshed"))

;;;###autoload
(defun cwt-launch (alias)
  "Launch a CloudWatch tail for ALIAS."
  (interactive
   (list (completing-read "CW tail: "
                          (mapcar #'car cwt-log-aliases) nil t)))
  (let* ((cmd (cwt--build-cmd alias))
         (bufname (cwt--buffer-name alias))
         (buf (get-buffer bufname)))
    (message "cwt: %s → %s" alias cmd)
    (if (and buf (get-buffer-process buf))
        (pop-to-buffer buf)
      (when buf (kill-buffer buf))
      (let* ((process-environment (append cwt-process-environment
                                          process-environment))
             (new-buf (make-comint-in-buffer alias bufname
                                             shell-file-name nil
                                             shell-command-switch cmd)))
        (with-current-buffer new-buf
          (cwt-mode)
          (face-remap-add-relative 'default
                                   :background (cwt--bg-for alias))
          (rename-buffer bufname t))
        (pop-to-buffer new-buf)))))

;;;###autoload
(defun cwt-launch-all ()
  "Launch all CloudWatch tail aliases, refreshing creds once."
  (interactive)
  (cwt--refresh-creds)
  (dolist (entry cwt-log-aliases)
    (cwt-launch (car entry))))

;;;###autoload
(defun cwt-stop (alias)
  "Stop the CloudWatch tail for ALIAS."
  (interactive
   (list (completing-read "Stop CW tail: "
                          (cl-remove-if-not
                           (lambda (a)
                             (let ((b (get-buffer (cwt--buffer-name a))))
                               (and b (get-buffer-process b))))
                           (mapcar #'car cwt-log-aliases))
                          nil t)))
  (let ((buf (get-buffer (cwt--buffer-name alias))))
    (when buf (kill-buffer buf))))

;;;###autoload
(defun cwt-stop-all ()
  "Stop all running CloudWatch tail buffers."
  (interactive)
  (dolist (entry cwt-log-aliases)
    (let ((buf (get-buffer (cwt--buffer-name (car entry)))))
      (when buf (kill-buffer buf)))))

(provide 'cloudwatch-tail)
;;; cloudwatch-tail.el ends here

;;; cloudwatch-tail.el --- Tail AWS CloudWatch log groups in comint buffers -*- lexical-binding: t; -*-

;;; Commentary:
;; Provides named comint buffers for tailing CloudWatch log groups.
;; Each buffer gets a tinted background and keyword highlighting for
;; ERROR / Exception (red) and SUCCESS (green) lines.
;;
;; Aliases are organized by namespace:
;;   ost/*  — ops-scheduledtagging Lambda/EventBridge log groups (static)
;;   ecs/*  — ECS service container log groups (dynamic, cached)
;;   mcp/*  — local MCP server log files (~/Library/Logs)
;;
;; Usage:
;;   C-c L  (cwt-launch)      – two-step: pick namespace, then pick log
;;   M-x cwt-launch-all       – open every ost/* alias at once
;;   M-x cwt-stop             – kill a running tail buffer
;;   M-x cwt-stop-all         – kill all tail buffers
;;   M-x cwt-ecs-refresh      – refresh the ECS log group cache

;;; Code:

(require 'comint)
(require 'ansi-color)
(require 'json)
(require 'cl-lib)
(require 'seq)

;; ── configuration ──────────────────────────────────────────────────
(defvar cwt-since "10m"
  "How far back to fetch logs on launch (e.g. \"1m\", \"5m\", \"1h\").")

(defvar cwt-ecs-clusters
  '("ecs-low" "ecs-mod01" "ecs-low01-stage" "ecs-mod01-stage"
    "ecs-low01-dev" "ecs-mod01-dev" "ecs-ops")
  "ECS cluster names to discover log groups from.")

(defvar cwt-ecs-cache-file
  (expand-file-name "~/.cache/cwt-ecs-cache.json")
  "File path for the ECS log group discovery cache.")

(defvar cwt-ecs-cache-ttl 3600
  "Cache TTL in seconds (default 1 hour).")

;; ── static ost/* aliases ───────────────────────────────────────────
(defvar cwt-log-aliases nil
  "Alist of (ALIAS . LOG-GROUP-OR-LIST).
Value is either a log group string, or a list of (LOG-GROUP &rest EXTRA-ARGS).")

(setq cwt-log-aliases
      '(("ost/resourcetagger"   . "/aws/lambda/ops-scheduledtagging-lambda-function")
        ("ost/qremove"          . "/aws/lambda/ops-scheduledtagging-delete-sqs-lambda")
        ("ost/statefailure"     . "/aws/lambda/ops-scheduledtagging-log-failure-lambda")
        ("ost/logbus"           . "/aws/events/ops-scheduledtagging-bus-cloudwatch-loggroup")
        ("ost/cesearch"         . "/aws/lambda/ops-scheduledtagging-cetobus-lambda-function")
        ("ost/qpush"            . "/aws/lambda/ops-scheduledtagging-populatesqs-lambda-function")
        ("ost/unenhancedlogbus" . "/aws/events/ops-scheduledtagging-unenhancedbus-cloudwatch-loggroup")
        ("ost/eventbridge_bus"  . "/aws/events/ops-scheduledtagging-eventbridge-bus")
        ("ost/acesearch"        . ("/aws/lambda/ops-scheduledtagging-resources-to-acebus-lambda-function" "--since" "1m"))
        ("ost/sandboxsearch"    . ("/aws/lambda/ops-scheduledtagging-resources-to-sandboxbus-lambda-function" "--since" "1m"))
        ("ost/bus_search"       . "/aws/lambda/ops-scheduledtagging-resources-to-bus-lambda-function")
        ("ost/loggroup_search"  . "/aws/lambda/ops-scheduledtagging-resources-to-loggroupbus-lambda-function")
        ("ost/check_dlq"        . "/aws/lambda/ops-scheduledtagging-check-dlq")
        ("ost/config_transform" . "/aws/lambda/ops-scheduledtagging-config-transform-lambda-function")
        ("ost/corrections"      . "/aws/lambda/ops-scheduledtagging-corrections-to-bus-lambda-function")
        ("ost/directclientlist" . "/aws/lambda/ops-scheduledtagging-search-directclientlist-lambda-function")
        ("ost/dynamo_scanner"   . "/aws/lambda/ops-scheduledtagging-dynamo-scanner")
        ("ost/expandarray"      . "/aws/lambda/ops-scheduledtagging-expandobjecttoarray-lambda-function")
        ("ost/fetch"            . "/aws/lambda/ops-scheduledtagging-fetch-lambda")
        ("ost/fetchaccounts"    . "/aws/lambda/ops-scheduledtagging-fetchaccounts-lambda-function")
        ("ost/receive_sqs"      . "/aws/lambda/ops-scheduledtagging-receive-sqs-lambda")
        ("ost/reprocess_dlq"    . "/aws/lambda/ops-scheduledtagging-reprocess-dlq")
        ("ost/s3_policy_eval"   . "/aws/lambda/ops-scheduledtagging-s3-policy-evaluator")
        ("ost/s3_policy_fix"    . "/aws/lambda/ops-scheduledtagging-s3-policy-remediation")
        ("ost/error"            . ("/aws/lambda/ops-scheduledtagging-lambda-function" "--filter-pattern" "?ERROR ?Exception"))
        ("ost/fail"             . ("/aws/lambda/ops-scheduledtagging-log-failure-lambda" "--filter-pattern" "TAGGING_FAILURE"))
        ("ost/success"          . ("/aws/lambda/ops-scheduledtagging-lambda-function" "--filter-pattern" "Successfully tagged resource"))))

;; ── static mcp/* aliases (local log files) ─────────────────────────
(defvar cwt-mcp-log-aliases
  `(("mcp/appfleet" . ,(expand-file-name "~/Library/Logs/mcp-appfleet.log"))
    ("mcp/entra"    . ,(expand-file-name "~/Library/Logs/mcp-entra.log"))
    ("mcp/ce"       . ,(expand-file-name "~/Library/Logs/mcp-ce.log"))
    ("mcp/ost"      . ,(expand-file-name "~/Library/Logs/mcp-ost.log")))
  "Alist of (ALIAS . LOG-FILE-PATH) for local MCP server logs.")

;; ── ECS discovery & caching ────────────────────────────────────────
(defvar cwt--ecs-cache nil
  "In-memory alist of (\"ecs/CLUSTER/SERVICE/CONTAINER\" . LOG-GROUP).")

(defvar cwt--ecs-cache-time 0
  "Epoch time when the ECS cache was last loaded.")

(defun cwt--ecs-cache-stale-p ()
  "Return non-nil if the ECS cache needs refreshing."
  (or (null cwt--ecs-cache)
      (> (- (float-time) cwt--ecs-cache-time) cwt-ecs-cache-ttl)))

(defun cwt--ecs-discover ()
  "Discover log groups from running ECS tasks across all configured clusters.
Returns an alist of (ALIAS . LOG-GROUP)."
  (message "cwt: discovering ECS log groups across %d clusters..." (length cwt-ecs-clusters))
  (let ((results nil))
    (dolist (cluster cwt-ecs-clusters)
      (condition-case err
          (let* ((svc-json (cwt--shell-command
                            (format "aws ecs list-services --cluster %s --query 'serviceArns' --output json 2>/dev/null"
                                    (shell-quote-argument cluster))))
                 (svc-arns (json-read-from-string svc-json)))
            (when (and svc-arns (> (length svc-arns) 0))
              (let ((arn-list (append svc-arns nil)))
                (while arn-list
                  (let* ((batch (seq-take arn-list 10))
                         (batch-str (mapconcat #'shell-quote-argument batch " "))
                         (desc-json (cwt--shell-command
                                     (format "aws ecs describe-services --cluster %s --services %s --query 'services[].{name: serviceName, td: taskDefinition}' --output json 2>/dev/null"
                                             (shell-quote-argument cluster) batch-str)))
                         (services (condition-case nil
                                      (json-read-from-string desc-json)
                                    (error nil))))
                    (when services
                      (dolist (svc (append services nil))
                        (let* ((svc-name (cdr (assq 'name svc)))
                               (td-arn (cdr (assq 'td svc))))
                          (when td-arn
                            (condition-case nil
                                (let* ((td-json (cwt--shell-command
                                                 (format "aws ecs describe-task-definition --task-definition %s --query 'taskDefinition.containerDefinitions[].{name: name, logGroup: logConfiguration.options.\"awslogs-group\"}' --output json 2>/dev/null"
                                                         (shell-quote-argument td-arn))))
                                       (containers (json-read-from-string td-json)))
                                  (dolist (c (append containers nil))
                                    (let ((cname (cdr (assq 'name c)))
                                          (lg (cdr (assq 'logGroup c))))
                                      (when (and cname lg (not (eq lg :null)))
                                        (push (cons (format "ecs/%s/%s/%s" cluster svc-name cname) lg)
                                              results)))))
                              (error nil)))))))
                  (setq arn-list (seq-drop arn-list 10))))))
        (error (message "cwt: error discovering %s: %s" cluster (error-message-string err)))))
    (message "cwt: discovered %d ECS log groups" (length results))
    (nreverse results)))

(defun cwt--ecs-save-cache (data)
  "Save DATA to the cache file."
  (let ((dir (file-name-directory cwt-ecs-cache-file)))
    (unless (file-directory-p dir) (make-directory dir t)))
  (with-temp-file cwt-ecs-cache-file
    (insert (json-encode data))))

(defun cwt--ecs-load-cache ()
  "Load the ECS cache from disk if it exists and is fresh enough."
  (when (file-exists-p cwt-ecs-cache-file)
    (let ((age (- (float-time) (float-time (file-attribute-modification-time
                                            (file-attributes cwt-ecs-cache-file))))))
      (when (< age cwt-ecs-cache-ttl)
        (condition-case nil
            (with-temp-buffer
              (insert-file-contents cwt-ecs-cache-file)
              (let* ((raw (json-read))
                     ;; json-read returns vector of vectors; convert to alist
                     (entries (mapcar (lambda (pair)
                                       (cons (aref pair 0) (aref pair 1)))
                                     (append raw nil))))
                entries))
          (error nil))))))

(defun cwt--ecs-ensure-cache ()
  "Ensure the ECS cache is populated, loading from disk or discovering."
  (unless cwt--ecs-cache
    (setq cwt--ecs-cache (cwt--ecs-load-cache))
    (when cwt--ecs-cache
      (setq cwt--ecs-cache-time (float-time))))
  (when (cwt--ecs-cache-stale-p)
    (let ((data (cwt--ecs-discover)))
      (setq cwt--ecs-cache data
            cwt--ecs-cache-time (float-time))
      (cwt--ecs-save-cache data)))
  cwt--ecs-cache)

;;;###autoload
(defun cwt-ecs-refresh ()
  "Force refresh the ECS log group cache."
  (interactive)
  (setq cwt--ecs-cache nil
        cwt--ecs-cache-time 0)
  (cwt--ecs-ensure-cache)
  (message "cwt: ECS cache refreshed — %d log groups" (length cwt--ecs-cache)))

;; ── command building ───────────────────────────────────────────────
(defun cwt--build-cmd (alias)
  "Build the full tail command string for ALIAS.
Uses `tail -f' for mcp/* aliases (local files), `aws logs tail' for others."
  (let ((mcp-entry (cdr (assoc alias cwt-mcp-log-aliases))))
    (if mcp-entry
        (format "tail -f %s" (shell-quote-argument mcp-entry))
      (let ((entry (cdr (assoc alias cwt-log-aliases))))
        (unless entry
          (setq entry (cdr (assoc alias (cwt--ecs-ensure-cache)))))
        (cond
         ((null entry) (error "Unknown alias: %s" alias))
         ((listp entry)
          (let* ((group (car entry))
                 (extra (cdr entry))
                 (has-since (member "--since" extra))
                 (since-part (if has-since "" (format " --since '%s'" cwt-since)))
                 (extra-str (mapconcat (lambda (s)
                                         (if (string-prefix-p "--" s) s
                                           (shell-quote-argument s)))
                                       extra " ")))
            (format "aws logs tail '%s' --follow%s %s" group since-part extra-str)))
         (t (format "aws logs tail '%s' --follow --since '%s'" entry cwt-since)))))))

;; ── per-buffer background tints ────────────────────────────────────
(defvar cwt--bg-colors-dark
  '(("ost/error"          . "#2a1515")
    ("ost/fail"           . "#2a1a15")
    ("ost/statefailure"   . "#2a1818")
    ("ost/success"        . "#152a15")
    ("ost/resourcetagger" . "#15192a")
    ("ost/qremove"        . "#15252a")
    ("ost/logbus"         . "#1a2015")
    ("ost/cesearch"       . "#1f1525")
    ("ost/qpush"          . "#151f2a")
    ("ost/unenhancedlogbus" . "#201a15")
    ("ost/acesearch"      . "#15201f")
    ("ost/sandboxsearch"  . "#1a1a20")
    ("ost/bus_search"     . "#1a1520")
    ("ost/loggroup_search" . "#15201a")
    ("ost/check_dlq"      . "#251518")
    ("ost/config_transform" . "#181a25")
    ("ost/corrections"    . "#1a2518")
    ("ost/directclientlist" . "#201518")
    ("ost/dynamo_scanner" . "#18251a")
    ("ost/eventbridge_bus" . "#1a1825")
    ("ost/expandarray"    . "#251a18")
    ("ost/fetch"          . "#181525")
    ("ost/fetchaccounts"  . "#25181a")
    ("ost/receive_sqs"    . "#151a25")
    ("ost/reprocess_dlq"  . "#251815")
    ("ost/s3_policy_eval" . "#1a2520")
    ("ost/s3_policy_fix"  . "#201a25"))
  "Per-alias background colors for dark themes.")

(defvar cwt--bg-colors-light
  '(("ost/error"          . "#fff0f0")
    ("ost/fail"           . "#fff5ee")
    ("ost/statefailure"   . "#fff0f5")
    ("ost/success"        . "#f0fff0")
    ("ost/resourcetagger" . "#f0f0ff")
    ("ost/qremove"        . "#f0faff")
    ("ost/logbus"         . "#f5fff0")
    ("ost/cesearch"       . "#faf0ff")
    ("ost/qpush"          . "#f0f5ff")
    ("ost/unenhancedlogbus" . "#fff8f0")
    ("ost/acesearch"      . "#f0fff8")
    ("ost/sandboxsearch"  . "#f5f5ff")
    ("ost/bus_search"     . "#f5f0fa")
    ("ost/loggroup_search" . "#f0faf5")
    ("ost/check_dlq"      . "#fff0f3")
    ("ost/config_transform" . "#f3f5ff")
    ("ost/corrections"    . "#f5fff3")
    ("ost/directclientlist" . "#faf0f3")
    ("ost/dynamo_scanner" . "#f3faf5")
    ("ost/eventbridge_bus" . "#f5f3ff")
    ("ost/expandarray"    . "#fff5f3")
    ("ost/fetch"          . "#f3f0ff")
    ("ost/fetchaccounts"  . "#fff3f5")
    ("ost/receive_sqs"    . "#f0f5fa")
    ("ost/reprocess_dlq"  . "#faf3f0")
    ("ost/s3_policy_eval" . "#f5fff8")
    ("ost/s3_policy_fix"  . "#f8f5ff"))
  "Per-alias background colors for light themes.")

(defun cwt--bg-for (alias)
  "Return background color for ALIAS, adapting to current theme."
  (let* ((light-p (eq (frame-parameter nil 'background-mode) 'light))
         (colors (if light-p cwt--bg-colors-light cwt--bg-colors-dark)))
    (or (cdr (assoc alias colors))
        ;; Generate a deterministic tint for ECS aliases
        (let ((hash (sxhash alias)))
          (if light-p
              (format "#%02x%02x%02x"
                      (+ 240 (mod hash 15))
                      (+ 240 (mod (/ hash 17) 15))
                      (+ 240 (mod (/ hash 31) 15)))
            (format "#%02x%02x%02x"
                    (+ 20 (mod hash 12))
                    (+ 20 (mod (/ hash 17) 12))
                    (+ 20 (mod (/ hash 31) 12))))))))

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
  "Convert UTC ISO-8601 timestamps to local time in the last comint output."
  (let ((start-marker comint-last-output-start)
        (end-marker (process-mark (get-buffer-process (current-buffer)))))
    (save-excursion
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
                                  0))
               (local (format-time-string "%Y-%m-%dT%H:%M:%S" time cwt-timezone))
               (offset (format-time-string "%z" time cwt-timezone))
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

(defun cwt--shell-command (cmd)
  "Run CMD with cwt-process-environment and return stdout string."
  (let ((process-environment (append cwt-process-environment process-environment)))
    (shell-command-to-string cmd)))

(defun cwt--refresh-creds ()
  "Refresh AWS credentials via the emacs-aws-refresh script."
  (interactive)
  (message "Refreshing AWS credentials...")
  (shell-command "/usr/local/bin/emacs-aws-refresh")
  (message "AWS credentials refreshed"))

(defun cwt--all-aliases ()
  "Return combined alist of static + MCP + ECS aliases."
  (append cwt-log-aliases cwt-mcp-log-aliases (cwt--ecs-ensure-cache)))

(defun cwt--namespace-keys ()
  "Return sorted list of unique namespace prefixes (e.g. \"ost\", \"ecs\")."
  (let ((ns (make-hash-table :test 'equal)))
    (dolist (entry (cwt--all-aliases))
      (when (string-match "\\`\\([^/]+\\)/" (car entry))
        (puthash (match-string 1 (car entry)) t ns)))
    (sort (hash-table-keys ns) #'string<)))

(defun cwt--aliases-in-namespace (ns)
  "Return aliases whose prefix matches NS."
  (let ((prefix (concat ns "/")))
    (cl-remove-if-not (lambda (e) (string-prefix-p prefix (car e)))
                      (cwt--all-aliases))))

(defun cwt--pick-ecs-alias ()
  "Two-step drill-down: cluster → service/container."
  (let* ((ecs-entries (cwt--aliases-in-namespace "ecs"))
         ;; Extract unique clusters
         (clusters (seq-uniq
                    (mapcar (lambda (e)
                              (nth 1 (split-string (car e) "/")))
                            ecs-entries)))
         (cluster (completing-read "ECS cluster: " (sort clusters #'string<) nil t))
         ;; Filter to this cluster, show service/container
         (prefix (concat "ecs/" cluster "/"))
         (in-cluster (cl-remove-if-not
                      (lambda (e) (string-prefix-p prefix (car e)))
                      ecs-entries))
         (display-alist (mapcar (lambda (e)
                                  (cons (string-remove-prefix prefix (car e))
                                        (car e)))
                                in-cluster))
         (choice (completing-read (format "Service/container [%s]: " cluster)
                                  (mapcar #'car display-alist) nil t)))
    (cdr (assoc choice display-alist))))

;;;###autoload
(defun cwt-launch (alias)
  "Launch a CloudWatch tail.
Two-step selection: first pick namespace (ost, ecs), then pick the log."
  (interactive
   (list
    (let* ((ns (completing-read "Log namespace: " (cwt--namespace-keys) nil t)))
      (if (string= ns "ecs")
          (cwt--pick-ecs-alias)
        ;; For non-ecs namespaces, show aliases within that namespace
        (let* ((entries (cwt--aliases-in-namespace ns))
               (prefix (concat ns "/"))
               (display-alist (mapcar (lambda (e)
                                        (cons (string-remove-prefix prefix (car e))
                                              (car e)))
                                      entries))
               (choice (completing-read (format "%s log: " ns)
                                        (mapcar #'car display-alist) nil t)))
          (cdr (assoc choice display-alist)))))))
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
  "Launch all ost/* CloudWatch tail aliases, refreshing creds once."
  (interactive)
  (cwt--refresh-creds)
  (dolist (entry (cwt--aliases-in-namespace "ost"))
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
                           (mapcar #'car (cwt--all-aliases)))
                          nil t)))
  (let ((buf (get-buffer (cwt--buffer-name alias))))
    (when buf (kill-buffer buf))))

;;;###autoload
(defun cwt-stop-all ()
  "Stop all running CloudWatch tail buffers."
  (interactive)
  (dolist (entry (cwt--all-aliases))
    (let ((buf (get-buffer (cwt--buffer-name (car entry)))))
      (when buf (kill-buffer buf)))))

(provide 'cloudwatch-tail)
;;; cloudwatch-tail.el ends here

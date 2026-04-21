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
    ("tag.log1"         . "/aws/lambda/ops-scheduledtagging-lambda-function")
    ("qremove"          . "/aws/lambda/ops-scheduledtagging-delete-sqs-lambda")
    ("statefailure"     . "/aws/lambda/ops-scheduledtagging-log-failure-lambda")
    ("logbus"           . "/aws/events/ops-scheduledtagging-bus-cloudwatch-loggroup")
    ("cesearch"         . "/aws/lambda/ops-scheduledtagging-cetobus-lambda-function")
    ("qpush"            . "/aws/lambda/ops-scheduledtagging-populatesqs-lambda-function")
    ("unenhancedlogbus" . "/aws/events/ops-scheduledtagging-unenhancedbus-cloudwatch-loggroup")
    ("acesearch"        . ("/aws/lambda/ops-scheduledtagging-resources-to-acebus-lambda-function" "--since" "1m"))
    ("sandboxsearch"    . "/aws/lambda/ops-scheduledtagging-resources-to-sandboxbus-lambda-function")
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
(defvar cwt--bg-colors
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
    ("sandboxsearch"  . "#1a1a20"))
  "Per-alias background colors.  Dark tints so text stays readable.")

(defun cwt--bg-for (alias)
  "Return background color for ALIAS, falling back to default."
  (or (cdr (assoc alias cwt--bg-colors)) "#1a1a1a"))

;; ── font-lock faces ───────────────────────────────────────────────
(defface cwt-error-face
  '((t :foreground "#ff6666" :weight bold))
  "Face for ERROR / Exception lines.")

(defface cwt-warn-face
  '((t :foreground "#ffaa44"))
  "Face for WARNING lines.")

(defface cwt-success-face
  '((t :foreground "#66ff88" :weight bold))
  "Face for success lines.")

(defface cwt-timestamp-face
  '((t :foreground "#888899"))
  "Face for CloudWatch timestamps.")

(defvar cwt-font-lock-keywords
  '(("\\(ERROR\\|Exception\\|Traceback\\|TAGGING_FAILURE\\)" 0 'cwt-error-face t)
    ("\\(WARN\\|WARNING\\)" 0 'cwt-warn-face t)
    ("\\(Successfully tagged resource\\|SUCCESS\\)" 0 'cwt-success-face t)
    ("^[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9:+.-]+" 0 'cwt-timestamp-face t))
  "Font-lock keywords for CloudWatch tail buffers.")

;; ── major mode ────────────────────────────────────────────────────
(define-derived-mode cwt-mode comint-mode "CW-Tail"
  "Major mode for tailing CloudWatch logs."
  (setq-local comint-process-echoes nil)
  (setq-local comint-scroll-to-bottom-on-output t)
  (ansi-color-for-comint-mode-on)
  (font-lock-add-keywords nil cwt-font-lock-keywords)
  (font-lock-mode 1)
  (setq buffer-read-only nil))

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

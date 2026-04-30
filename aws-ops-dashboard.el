;;; aws-ops-dashboard.el --- SQS + DynamoDB monitoring for ops-scheduledtagging -*- lexical-binding: t; -*-

;;; Commentary:
;; Interactive dashboard for monitoring ops-scheduledtagging SQS queues
;; and DynamoDB tables from Emacs.  Uses tabulated-list-mode for tables,
;; auto-refresh timers, and JSON pretty-printing for message inspection.
;;
;; Usage:
;;   M-x aod-status          – show queue counts + DynamoDB counts
;;   M-x aod-watch           – auto-refresh status every N seconds
;;   M-x aod-watch-stop      – stop auto-refresh
;;   M-x aod-sample-messages – peek at messages in a queue
;;   M-x aod-dynamo-scan     – browse DynamoDB table items
;;   M-x aod-purge-queue     – purge a queue (with confirmation)

;;; Code:

(require 'json)
(require 'cl-lib)

;; ── configuration ─────────────────────────────────────────────────
(defvar aod-refresh-interval 30
  "Seconds between auto-refresh ticks.")

(defvar aod-region "us-west-2"
  "AWS region.")

(defvar aod-terraform-dir
  (expand-file-name "~/src/ops-projects-wt/ops-scheduled-tagging/ops-scheduled-tagging/terraform/")
  "Directory containing terraform outputs for queue URLs.")

(defvar aod-sqs-queues
  '(("Main"      . "sqs_queue_url")
    ("DLQ"       . "dlq_queue_url")
    ("Transform" . "transform_queue_url"))
  "Alist of (LABEL . TERRAFORM-OUTPUT-NAME) for SQS queues.")

(defvar aod-dynamo-tables
  '(("Processed"    . "ops-scheduledtagging-processed-resources")
    ("Preprocessed" . "ops-scheduledtagging-preprocessed-resources"))
  "Alist of (LABEL . TABLE-NAME) for DynamoDB tables.")

(defvar aod-process-environment
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
  "AWS env vars (same as cloudwatch-tail).")

;; ── internal helpers ──────────────────────────────────────────────
(defvar aod--queue-url-cache (make-hash-table :test 'equal)
  "Cache terraform output → queue URL.")

(defvar aod--watch-timer nil
  "Timer for auto-refresh.")

(defun aod--aws-cmd (args)
  "Run aws CLI with ARGS (string), return stdout string."
  (let ((process-environment (append aod-process-environment process-environment)))
    (with-temp-buffer
      (let ((exit-code (call-process "aws" nil t nil
                                     shell-command-switch
                                     (format "aws %s --region %s --output json" args aod-region))))
        (if (zerop exit-code)
            (buffer-string)
          (error "aws command failed: %s" (buffer-string)))))))

(defun aod--shell-cmd (cmd)
  "Run CMD in shell with AWS env, return stdout."
  (let ((process-environment (append aod-process-environment process-environment)))
    (string-trim (shell-command-to-string cmd))))

(defun aod--queue-url (tf-output-name)
  "Get queue URL from terraform output, cached."
  (or (gethash tf-output-name aod--queue-url-cache)
      (let ((url (aod--shell-cmd
                  (format "cd %s && terraform output -raw %s 2>/dev/null"
                          (shell-quote-argument aod-terraform-dir)
                          tf-output-name))))
        (when (and url (not (string-empty-p url)))
          (puthash tf-output-name url aod--queue-url-cache))
        url)))

(defun aod--sqs-count (tf-output-name)
  "Get ApproximateNumberOfMessages for queue."
  (let ((url (aod--queue-url tf-output-name)))
    (if (and url (not (string-empty-p url)))
        (let* ((out (aod--shell-cmd
                     (format "aws sqs get-queue-attributes --queue-url '%s' --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed --region %s --output json"
                             url aod-region)))
               (json (json-read-from-string out))
               (attrs (cdr (assq 'Attributes json))))
          `((visible . ,(string-to-number (or (cdr (assq 'ApproximateNumberOfMessages attrs)) "0")))
            (in-flight . ,(string-to-number (or (cdr (assq 'ApproximateNumberOfMessagesNotVisible attrs)) "0")))
            (delayed . ,(string-to-number (or (cdr (assq 'ApproximateNumberOfMessagesDelayed attrs)) "0")))))
      '((visible . -1) (in-flight . -1) (delayed . -1)))))

(defun aod--dynamo-count (table-name)
  "Get item count for DynamoDB TABLE-NAME."
  (let* ((out (aod--shell-cmd
               (format "aws dynamodb describe-table --table-name '%s' --region %s --query 'Table.ItemCount' --output text"
                       table-name aod-region)))
         (n (string-to-number (string-trim out))))
    n))

;; ── faces ─────────────────────────────────────────────────────────
(defface aod-zero-face
  '((t :foreground "#66ff88"))
  "Face for zero counts (healthy).")

(defface aod-nonzero-face
  '((t :foreground "#ff6666" :weight bold))
  "Face for non-zero counts (attention needed).")

(defface aod-header-face
  '((t :foreground "#88aaff" :weight bold))
  "Face for section headers.")

(defface aod-label-face
  '((t :foreground "#ccccdd"))
  "Face for labels.")

;; ── status dashboard ──────────────────────────────────────────────
(defun aod--format-count (n &optional zero-is-good)
  "Format count N with appropriate face."
  (let ((s (if (< n 0) "N/A" (number-to-string n))))
    (if (and zero-is-good (= n 0))
        (propertize s 'face 'aod-zero-face)
      (if (> n 0)
          (propertize s 'face 'aod-nonzero-face)
        (propertize s 'face 'aod-zero-face)))))

(defun aod--render-status (buf)
  "Render the status dashboard into BUF."
  (with-current-buffer buf
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (propertize "═══ ops-scheduledtagging Dashboard ═══\n" 'face 'aod-header-face))
      (insert (propertize (format-time-string "  Updated: %Y-%m-%d %H:%M:%S\n\n") 'face 'font-lock-comment-face))

      ;; SQS Queues
      (insert (propertize "── SQS Queues ──\n" 'face 'aod-header-face))
      (insert (format "  %-12s %8s %10s %8s\n"
                      (propertize "Queue" 'face 'aod-label-face)
                      (propertize "Visible" 'face 'aod-label-face)
                      (propertize "In-Flight" 'face 'aod-label-face)
                      (propertize "Delayed" 'face 'aod-label-face)))
      (insert "  ─────────── ──────── ────────── ────────\n")
      (dolist (q aod-sqs-queues)
        (let* ((counts (condition-case err
                           (aod--sqs-count (cdr q))
                         (error '((visible . -1) (in-flight . -1) (delayed . -1)))))
               (vis (cdr (assq 'visible counts)))
               (inf (cdr (assq 'in-flight counts)))
               (del (cdr (assq 'delayed counts))))
          (insert (format "  %-12s %8s %10s %8s\n"
                          (propertize (car q) 'face 'aod-label-face)
                          (aod--format-count vis t)
                          (aod--format-count inf t)
                          (aod--format-count del t)))))

      ;; DynamoDB Tables
      (insert (propertize "\n── DynamoDB Tables ──\n" 'face 'aod-header-face))
      (insert (format "  %-16s %10s\n"
                      (propertize "Table" 'face 'aod-label-face)
                      (propertize "Items" 'face 'aod-label-face)))
      (insert "  ──────────────── ──────────\n")
      (dolist (tbl aod-dynamo-tables)
        (let ((count (condition-case nil
                         (aod--dynamo-count (cdr tbl))
                       (error -1))))
          (insert (format "  %-16s %10s\n"
                          (propertize (car tbl) 'face 'aod-label-face)
                          (aod--format-count count)))))

      (insert (propertize "\n── Keys ──\n" 'face 'aod-header-face))
      (insert "  g = refresh  w = watch  W = stop watch  s = sample  d = dynamo scan  P = purge\n"))))

(defvar aod-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'aod-status)
    (define-key map (kbd "w") #'aod-watch)
    (define-key map (kbd "W") #'aod-watch-stop)
    (define-key map (kbd "s") #'aod-sample-messages)
    (define-key map (kbd "d") #'aod-dynamo-scan)
    (define-key map (kbd "P") #'aod-purge-queue)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for aod-mode.")

(define-derived-mode aod-mode special-mode "AOD"
  "Major mode for ops-scheduledtagging dashboard."
  (setq-local revert-buffer-function (lambda (_ignore-auto _noconfirm) (aod-status)))
  (buffer-disable-undo))

;;;###autoload
(defun aod-status ()
  "Show ops-scheduledtagging SQS + DynamoDB status dashboard."
  (interactive)
  (let ((buf (get-buffer-create "*aod-status*")))
    (aod--render-status buf)
    (with-current-buffer buf
      (aod-mode)
      (goto-char (point-min)))
    (pop-to-buffer buf)))

;;;###autoload
(defun aod-watch ()
  "Auto-refresh the status dashboard every `aod-refresh-interval' seconds."
  (interactive)
  (aod-watch-stop)
  (aod-status)
  (setq aod--watch-timer
        (run-with-timer aod-refresh-interval aod-refresh-interval
                        (lambda ()
                          (when (get-buffer "*aod-status*")
                            (aod--render-status (get-buffer "*aod-status*")))))))

;;;###autoload
(defun aod-watch-stop ()
  "Stop auto-refresh."
  (interactive)
  (when aod--watch-timer
    (cancel-timer aod--watch-timer)
    (setq aod--watch-timer nil)
    (message "aod: watch stopped")))

;; ── sample messages ───────────────────────────────────────────────
;;;###autoload
(defun aod-sample-messages (label)
  "Peek at messages in a queue (does NOT delete them)."
  (interactive
   (list (completing-read "Queue: " (mapcar #'car aod-sqs-queues) nil t)))
  (let* ((tf-name (cdr (assoc label aod-sqs-queues)))
         (url (aod--queue-url tf-name))
         (out (aod--shell-cmd
               (format "aws sqs receive-message --queue-url '%s' --max-number-of-messages 5 --visibility-timeout 0 --region %s --output json"
                       url aod-region)))
         (buf (get-buffer-create (format "*aod-messages:%s*" label))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (format "── %s Queue Messages ──\n\n" label) 'face 'aod-header-face))
        (if (or (string-empty-p out) (string= out "{}"))
            (insert (propertize "  (empty)\n" 'face 'font-lock-comment-face))
          (condition-case nil
              (let* ((json-obj (json-read-from-string out))
                     (msgs (cdr (assq 'Messages json-obj))))
                (if (not msgs)
                    (insert (propertize "  (no messages)\n" 'face 'font-lock-comment-face))
                  (dotimes (i (length msgs))
                    (let* ((msg (aref msgs i))
                           (body (cdr (assq 'Body msg)))
                           (id (cdr (assq 'MessageId msg))))
                      (insert (propertize (format "── Message %d ── %s\n" (1+ i) (or id "")) 'face 'aod-label-face))
                      (condition-case nil
                          (insert (with-temp-buffer
                                    (insert body)
                                    (json-pretty-print-buffer)
                                    (buffer-string)))
                        (error (insert body)))
                      (insert "\n\n")))))
            (error (insert out)))))
      (js-mode)
      (goto-char (point-min))
      (setq buffer-read-only t))
    (pop-to-buffer buf)))

;; ── DynamoDB scan ─────────────────────────────────────────────────
;;;###autoload
(defun aod-dynamo-scan (label)
  "Browse items in a DynamoDB table (first 25 items)."
  (interactive
   (list (completing-read "Table: " (mapcar #'car aod-dynamo-tables) nil t)))
  (let* ((table-name (cdr (assoc label aod-dynamo-tables)))
         (out (aod--shell-cmd
               (format "aws dynamodb scan --table-name '%s' --region %s --max-items 25 --output json"
                       table-name aod-region)))
         (buf (get-buffer-create (format "*aod-dynamo:%s*" label))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (format "── %s (%s) ──\n\n" label table-name) 'face 'aod-header-face))
        (condition-case nil
            (let* ((json-obj (json-read-from-string out))
                   (items (cdr (assq 'Items json-obj)))
                   (count (cdr (assq 'Count json-obj))))
              (insert (format "  Showing %d items\n\n" (or count 0)))
              (dotimes (i (length items))
                (insert (propertize (format "── Item %d ──\n" (1+ i)) 'face 'aod-label-face))
                (insert (with-temp-buffer
                          (insert (json-encode (aref items i)))
                          (json-pretty-print-buffer)
                          (buffer-string)))
                (insert "\n\n")))
          (error (insert out))))
      (js-mode)
      (goto-char (point-min))
      (setq buffer-read-only t))
    (pop-to-buffer buf)))

;; ── purge queue ───────────────────────────────────────────────────
;;;###autoload
(defun aod-purge-queue (label)
  "Purge all messages from a queue (with confirmation)."
  (interactive
   (list (completing-read "Purge queue: " (mapcar #'car aod-sqs-queues) nil t)))
  (when (yes-or-no-p (format "PURGE all messages from %s queue? " label))
    (let* ((tf-name (cdr (assoc label aod-sqs-queues)))
           (url (aod--queue-url tf-name)))
      (aod--shell-cmd
       (format "aws sqs purge-queue --queue-url '%s' --region %s" url aod-region))
      (message "aod: %s queue purged" label)
      (when (get-buffer "*aod-status*")
        (aod-status)))))

(provide 'aws-ops-dashboard)
;;; aws-ops-dashboard.el ends here

;;; dot-org-jira.el --- org-jira configuration for Jira Server -*- lexical-binding: t -*-

;;; Commentary:
;; Customizations for org-jira against Jira Server (API v2).
;; Includes: PAT auth, Jira Server field patches, org-capture integration.
;;
;; Built-in org-jira commands for managing issues in ~/.org-jira/:
;;   org-jira-get-issues-from-custom-jql  — pull issues from Jira via saved JQLs
;;   org-jira-refresh-issue               — refresh current issue from Jira
;;   org-jira-refresh-issues-in-buffer    — refresh all issues in buffer
;;   org-jira-progress-issue              — transition issue workflow
;;   org-jira-todo-to-jira                — push TODO state change to Jira
;;   org-jira-browse-issue                — open issue in browser
;;
;; Custom commands (for creating issues from org headings in todo.txt):
;;   org-jira-create-from-heading  (C-c j c) — create Jira issue from org heading

;;; Code:

(require 'seq)

;; Disable org-element cache globally — it causes extreme slowness
;; when org-jira programmatically modifies org buffers
(setq org-element-use-cache nil)

;; Color-code Jira agenda items by story points
;; Uses modus-operandi-compatible colors
(defface my/jira-sp-xs '((t :foreground "#005e00")) "Story points: 0-1 (extra small)")  ; green
(defface my/jira-sp-sm '((t :foreground "#813e00")) "Story points: 2 (small)")           ; brown/amber
(defface my/jira-sp-md '((t :foreground "#0031a9")) "Story points: 3-5 (medium)")        ; blue
(defface my/jira-sp-lg '((t :foreground "#721045")) "Story points: 8+ (large)")          ; magenta
(defface my/jira-active-sprint
  '((t :weight bold))
  "Face for issues in the active sprint.")
(defface my/jira-sprint-prefix
  '((t :foreground "#5317ac" :weight light))
  "Face for the sprint name column.")

;; org-super-agenda for grouped Jira views
(use-package org-super-agenda
  :config
  (org-super-agenda-mode 1))
(defface my/jira-tag-issue-id
  '((t :foreground "#8f0075"))
  "Face for the issue ID tag.")
(defface my/jira-tag-epic
  '((t :foreground "#0031a9" :weight bold))
  "Face for the epic short name tag.")
(defface my/jira-tag-sp
  '((t :foreground "#005e00" :weight bold))
  "Face for the story points tag.")
(defface my/jira-tag-active
  '((t :foreground "#a60000" :weight bold))
  "Face for the ACTIVE tag.")
(defface my/jira-tag-label
  '((t :foreground "#30517f"))
  "Face for Jira label tags.")

(defun my/org-jira-colorize-agenda ()
  "Colorize Jira agenda lines: sprint prefix, tags, active sprint emphasis."
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let ((marker (get-text-property (point) 'org-marker))
            (bol (line-beginning-position))
            (eol (line-end-position)))
        (when marker
          (let* ((tags (org-entry-get marker "ALLTAGS"))
                 (active-p (and tags (string-match-p ":ACTIVE:" tags))))
            ;; Bold the whole line for active sprint
            (when active-p
              (add-face-text-property bol eol 'my/jira-active-sprint t))
            ;; Color the sprint prefix (first ~30 chars)
            (let ((prefix-end (min (+ bol 32) eol)))
              (add-face-text-property bol prefix-end 'my/jira-sprint-prefix t))
            ;; Color individual tags at end of line
            (save-excursion
              (goto-char bol)
              (while (re-search-forward ":\\([^:]+\\):" eol t)
                (let ((tag (match-string 1))
                      (mbeg (match-beginning 0))
                      (mend (match-end 0)))
                  (cond
                   ((string-match-p "^CO_" tag)
                    (add-face-text-property mbeg mend 'my/jira-tag-issue-id t))
                   ((string-match-p "^SP_" tag)
                    (add-face-text-property mbeg mend 'my/jira-tag-sp t))
                   ((string= tag "ACTIVE")
                    (add-face-text-property mbeg mend 'my/jira-tag-active t))
                   ((string-match-p "^\\(maintenance\\|Stratus\\|Infrastructure\\|AI_ML\\|af2_migrate\\)" tag)
                    (add-face-text-property mbeg mend 'my/jira-tag-label t))
                   (t  ; epic short name and other tags
                    (add-face-text-property mbeg mend 'my/jira-tag-epic t)))))))))
      (forward-line 1))))

;; Custom agenda comparator: sort by sprint with Backlog last
(defun my/org-jira-sprint-sort (a b)
  "Sort agenda items by sprint (Backlog last), then TODO state (NEXT before TODO), then priority."
  (let* ((ma (org-find-text-property-in-string 'org-marker a))
         (mb (org-find-text-property-in-string 'org-marker b))
         (sprint-a (or (and ma (org-entry-get ma "sprint")) "zzz-Backlog"))
         (sprint-b (or (and mb (org-entry-get mb "sprint")) "zzz-Backlog"))
         ;; TODO state ordering: NEXT=1, TODO=2, HOLD=3, DONE=4, CANCELLED=5
         (state-order '(("NEXT" . 1) ("TODO" . 2) ("HOLD" . 3) ("DONE" . 4) ("CANCELLED" . 5)))
         (state-a (or (cdr (assoc (get-text-property 1 'todo-state a) state-order)) 9))
         (state-b (or (cdr (assoc (get-text-property 1 'todo-state b) state-order)) 9)))
    (cond ((string< sprint-a sprint-b) -1)
          ((string< sprint-b sprint-a) +1)
          ((< state-a state-b) -1)
          ((> state-a state-b) +1)
          (t nil))))

(use-package org-jira
  :load-path "~/src/org-jira"
  :defer t
  :commands (org-jira-get-issues org-jira-get-issues-from-custom-jql
             org-jira-create-issue org-jira-browse-issue
             org-jira-progress-issue org-jira-refresh-issue)
  :init
  (setq jiralib-url "https://jira.example.com")
  (setq jiralib-target-api-version 2)
  (setq org-jira-users '(("Unassigned" . nil)))
  (make-directory "~/.org-jira" t)
  (setq org-jira-working-dir "~/.org-jira")
  (setq jiralib-token
        (cons "Authorization"
              (concat "Bearer "
                      (string-trim
                       (shell-command-to-string
                        "/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:JIRA_TOKEN' ~/Library/LaunchAgents/mcp-jira.plist")))))

  ;; Disable worklog and comment sync by default for fast fetching
  ;; Use C-c j C to download comments for the issue at point
  (setq org-jira-worklog-sync-p nil)
  (setq org-jira-download-comments nil)

  ;; Map Jira statuses to org TODO keywords
  (setq org-jira-jira-status-to-org-keyword-alist
        '(("Ready" . "TODO")
          ("On Deck" . "TODO")
          ("On Hold" . "HOLD")
          ("In Progress" . "NEXT")
          ("Testing" . "NEXT")
          ("Testing/Acceptance" . "NEXT")
          ("Review" . "NEXT")
          ("Blocked" . "HOLD")
          ("Done" . "DONE")
          ("Cancelled" . "CANCELLED")
          ("Rejected" . "CANCELLED")))
  (setq org-jira-verbosity 'debug)

  ;; Map Jira custom fields to org properties
  (setq org-jira-custom-field-mappings
        '((customfield_10002 . "story-points")
          (customfield_10006 . "epic")
          (customfield_10007 . "epic-name")
          (customfield_11400 . "servicenow-link")))

  ;; Disable org-element cache during org-jira rendering — the cache
  ;; causes extreme slowness when programmatically modifying org buffers
  (defun my/org-jira-disable-element-cache (orig-fn &rest args)
    "Disable org-element cache during org-jira issue rendering."
    (let ((org-element-use-cache nil))
      (apply orig-fn args)))
  (advice-add 'org-jira--render-issues-from-issue-list
              :around #'my/org-jira-disable-element-cache)

  ;; Map Jira priorities to org priority cookies so org-agenda doesn't choke
  (setq org-jira-priority-to-org-priority-alist
        '(("Blocker"  . ?A)
          ("Critical" . ?A)
          ("Major"    . ?B)
          ("Minor"    . ?C)
          ("Trivial"  . ?C)))

  ;; org-jira writes a :priority: property that clashes with org-mode's
  ;; built-in PRIORITY handling. When org-agenda scans deadlines, it calls
  ;; format with nil because the priority cookie is missing on existing
  ;; headings. Patch org-agenda-get-deadlines to handle this gracefully.
  (with-eval-after-load 'org-agenda
    (defun my/org-agenda-fix-nil-priority (orig-fn &rest args)
      "Wrap org-agenda-get-deadlines to catch nil format string errors."
      (condition-case nil
          (apply orig-fn args)
        (wrong-type-argument nil)))
    (advice-add 'org-agenda-get-deadlines :around #'my/org-agenda-fix-nil-priority)
    (advice-add 'org-agenda-get-scheduled :around #'my/org-agenda-fix-nil-priority))
  :config
  ;; Jira Server doesn't have /rest/api/2/label endpoint (Cloud-only).
  (defun org-jira-read-labels ()
    (condition-case nil
        (let* ((response (jiralib-do-jql-search
                          "project = CO AND labels is not EMPTY" 100))
               (labels (make-hash-table :test 'equal)))
          (dolist (issue response)
            (dolist (label (org-jira-find-value issue 'fields 'labels))
              (puthash label t labels)))
          (hash-table-keys labels))
      (error nil)))

  ;; Jira Server expects assignee as {"name": "username"} not {"accountId": "..."}
  (defun org-jira-get-issue-struct (project type summary description &optional parent-id)
    "Create an issue struct for PROJECT, of TYPE, with SUMMARY and DESCRIPTION.
Patched for Jira Server: uses 'name' instead of 'accountId' for assignee."
    (if (or (equal project "") (equal type "") (equal summary ""))
        (error "Must provide all information!"))
    (let* ((project-components (jiralib-get-components project))
           (jira-users (org-jira-get-assignable-users project))
           (user (completing-read "Assignee: " (mapcar #'car jira-users)))
           (priority (car (rassoc (org-jira-read-priority) (jiralib-get-priorities))))
           (labels (org-jira-read-labels))
           (ticket-fields
            `((project (key . ,project))
              (parent (key . ,parent-id))
              (issuetype (id . ,(car (rassoc type
                                             (if (and (boundp 'parent-id) parent-id)
                                                 (jiralib-get-subtask-types)
                                               (jiralib-get-issue-types-by-project project))))))
              (summary . ,(format "%s%s" summary
                                  (if (and (boundp 'parent-id) parent-id)
                                      (format " (subtask of [jira:%s])" parent-id)
                                    "")))
              (description . ,description)
              (priority (id . ,priority))
              (labels . ,labels)
              (assignee (name . ,(cdr (assoc user jira-users))))))
           (filtered-fields (jiralib-filter-fields-by-exclude-list
                             jiralib-update-issue-fields-exclude-list
                             ticket-fields))
           (ticket-struct `((fields . ,filtered-fields))))
      ticket-struct))

  (setq org-jira-custom-jqls
        '(;; Only sync my issues by default
          (:jql "project = CO AND assignee = dhaley AND statusCategory != Done ORDER BY updated DESC"
                :limit 200
                :filename "co-dhaley")))

  (setq org-jira-default-jql "project = CO AND assignee = dhaley AND statusCategory != Done ORDER BY updated DESC")

  ;; Override SDK to extract sprint name from customfield_10005 (Jira Server)
  ;; and add story points from customfield_10002.
  (defun my/org-jira-extract-sprint-name (sprint-field)
    "Extract sprint name from Jira Server's customfield_10005 value.
The value is either a string like 'com.atlassian...Sprint@...[...,name=FY26 ...,...]'
or an alist with a 'name' key."
    (cond
     ((null sprint-field) nil)
     ((stringp sprint-field)
      (if (string-match "name=\\([^],]+\\)" sprint-field)
          (match-string 1 sprint-field)
        sprint-field))
     ((and (listp sprint-field) (cdr (assoc 'name sprint-field))))
     ;; Array of sprints — take the last (most recent)
     ((vectorp sprint-field)
      (my/org-jira-extract-sprint-name (aref sprint-field (1- (length sprint-field)))))
     (t nil)))

  (cl-defmethod org-jira-sdk-from-data ((rec org-jira-sdk-issue))
    (cl-flet ((path (keys) (org-jira-sdk-path (oref rec data) keys)))
      (org-jira-sdk-issue
       :assignee (path '(fields assignee displayName))
       :components (mapconcat (lambda (c) (org-jira-sdk-path c '(name))) (path '(fields components)) ", ")
       :labels (mapconcat (lambda (c) (format "%s" c)) (mapcar #'identity (path '(fields labels))) ", ")
       :created (path '(fields created))
       :description (or (path '(renderedFields description)) (or (path '(fields description)) ""))
       :duedate (or (path '(fields duedate)) (path '(fields sprint endDate)))
       :filename (path '(fields project key))
       :headline (path '(fields summary))
       :id (path '(key))
       :issue-id (path '(key))
       :issue-id-int (path '(id))
       :parent-key (path '(fields parent key))
       :priority (path '(fields priority name))
       :proj-key (path '(fields project key))
       :reporter (path '(fields reporter displayName))
       :resolution (path '(fields resolution name))
       :sprint (or (my/org-jira-extract-sprint-name (path '(fields customfield_10005)))
                   (path '(fields sprint name)))
       :start-date (path '(fields start-date))
       :status (org-jira-decode (path '(fields status name)))
       :summary (path '(fields summary))
       :type (path '(fields issuetype name))
       :type-id (path '(fields issuetype id))
       :updated (path '(fields updated))
       :data (oref rec data))))

  ;; Cache for epic key -> name lookups
  (defvar my/org-jira-epic-cache (make-hash-table :test 'equal))

  (defun my/org-jira-get-epic-name (epic-key)
    "Get epic name for EPIC-KEY, using cache."
    (or (gethash epic-key my/org-jira-epic-cache)
        (condition-case nil
            (let* ((issue (car (jiralib-do-jql-search (format "key = %s" epic-key) 1)))
                   (name (cdr (assoc 'customfield_10007 (cdr (assoc 'fields issue))))))
              (when name (puthash epic-key name my/org-jira-epic-cache))
              name)
          (error nil)))))

;; Enrich org-jira files with custom fields (story points, epic)
;; Run after org-jira-get-issues-from-custom-jql completes
(defun org-jira-enrich-buffer ()
  "Add story points and epic name to all issues in current org-jira buffer."
  (interactive)
  (require 'org-jira)
  (save-excursion
    (goto-char (point-min))
    (let ((count 0))
      (while (re-search-forward "^:CUSTOM_ID: +\\(\\S-+\\)" nil t)
        (let* ((issue-id (match-string-no-properties 1))
               (issue (car (jiralib-do-jql-search (format "key = %s" issue-id) 1)))
               (fields (cdr (assoc 'fields issue)))
               (sp (cdr (assoc 'customfield_10002 fields)))
               (epic-key (cdr (assoc 'customfield_10006 fields)))
               (epic-name (cdr (assoc 'customfield_10007 fields))))
          ;; Delete old custom props if present
          (save-excursion
            (let ((bound (save-excursion (re-search-forward "^:END:" nil t))))
              (when bound
                (while (re-search-forward "^:\\(story-points\\|epic\\|epic-name\\):.*\n" bound t)
                  (replace-match "")))))
          ;; Insert after CUSTOM_ID line
          (end-of-line)
          (when sp (insert (format "\n:story-points: %g" sp)))
          (when epic-key
            (insert (format "\n:epic: %s" epic-key))
            (let ((name (or epic-name (my/org-jira-get-epic-name epic-key))))
              (when name (insert (format "\n:epic-name: %s" name)))))
          (when (and epic-name (not epic-key))
            (insert (format "\n:epic-name: %s" epic-name)))
          (setq count (1+ count))
          (message "Enriched %d issues..." count)))
      (message "Enriched %d issues with story points and epic links" count))))

;;; ── Dynamic capture defaults ──

(defun org-jira--last-business-day-next-month ()
  "Return the last business day (Mon-Fri) of next month as yyyy-MM-dd."
  (let* ((now (decode-time))
         (month (nth 4 now))
         (year (nth 5 now))
         (next-month (if (= month 12) 1 (1+ month)))
         (next-year (if (= month 12) (1+ year) year))
         (after-month (if (= next-month 12) 1 (1+ next-month)))
         (after-year (if (= next-month 12) (1+ next-year) next-year))
         (last-day (nth 3 (decode-time (encode-time 0 0 0 0 after-month after-year))))
         (last-time (encode-time 0 0 12 last-day next-month next-year))
         (dow (nth 6 (decode-time last-time))))
    (when (= dow 0) (setq last-day (- last-day 2)))
    (when (= dow 6) (setq last-day (- last-day 1)))
    (format "%04d-%02d-%02d" next-year next-month last-day)))

(defun org-jira--next-sprint-name (project)
  "Return the name of the sprint following the active sprint in PROJECT."
  (require 'org-jira)
  (condition-case err
      (let* ((boards (jiralib--rest-call-it
                      (format "/rest/agile/1.0/board?projectKeyOrId=%s&type=scrum" project)
                      :type "GET"))
             (board-id (cdr (assoc 'id (aref (cdr (assoc 'values boards)) 0))))
             (active (jiralib--rest-call-it
                      (format "/rest/agile/1.0/board/%s/sprint?state=active" board-id)
                      :type "GET"))
             (active-list (append (cdr (assoc 'values active)) nil))
             (current (seq-find (lambda (s) (string-match-p "StratusOps Sprint" (cdr (assoc 'name s))))
                                active-list))
             (future (jiralib--rest-call-it
                      (format "/rest/agile/1.0/board/%s/sprint?state=future" board-id)
                      :type "GET"))
             (future-list (append (cdr (assoc 'values future)) nil))
             (next (seq-find (lambda (s) (string-match-p "StratusOps Sprint" (cdr (assoc 'name s))))
                             future-list)))
        (cond
         (next (cdr (assoc 'name next)))
         (current
          (let ((name (cdr (assoc 'name current))))
            (if (string-match "\\(.*Sprint \\)\\([0-9]+\\)" name)
                (format "%s%d" (match-string 1 name)
                        (1+ (string-to-number (match-string 2 name))))
              "")))
         (t "")))
    (error "")))

(defvar org-jira--capture-defaults-cache nil
  "Cached (sprint . due-date) for current capture session.")

(defun org-jira--capture-defaults ()
  "Return and cache default (sprint . due-date) for Jira Task capture."
  (or org-jira--capture-defaults-cache
      (setq org-jira--capture-defaults-cache
            (cons (org-jira--next-sprint-name "CO")
                  (org-jira--last-business-day-next-month)))))

(defun org-jira--capture-default-sprint ()
  "Return default sprint name for capture template."
  (car (org-jira--capture-defaults)))

(defun org-jira--capture-default-due-date ()
  "Return default due date for capture template."
  (prog1 (cdr (org-jira--capture-defaults))
    (setq org-jira--capture-defaults-cache nil)))

;;; ── Create Jira issues from org headings ──

(defun org-jira--resolve-epic-key (project epic-name)
  "Look up the issue key for an epic by EPIC-NAME in PROJECT."
  (require 'org-jira)
  (let* ((results (jiralib-do-jql-search
                   (format "project = %s AND issuetype = Epic AND \"Epic Name\" = \"%s\"" project epic-name)
                   1))
         (issue (car results)))
    (if issue
        (cdr (assoc 'key issue))
      (error "Epic not found: %s" epic-name))))

(defun org-jira--resolve-sprint-id (project sprint-name)
  "Look up the numeric sprint ID for SPRINT-NAME in PROJECT's scrum board."
  (require 'org-jira)
  (let* ((boards (jiralib--rest-call-it
                  (format "/rest/agile/1.0/board?projectKeyOrId=%s&type=scrum" project)
                  :type "GET"))
         (board-id (cdr (assoc 'id (aref (cdr (assoc 'values boards)) 0))))
         (sprints (jiralib--rest-call-it
                   (format "/rest/agile/1.0/board/%s/sprint?state=active,future" board-id)
                   :type "GET"))
         (sprint-list (append (cdr (assoc 'values sprints)) nil))
         (match (seq-find (lambda (s) (string= (cdr (assoc 'name s)) sprint-name))
                          sprint-list)))
    (if match
        (cdr (assoc 'id match))
      (error "Sprint not found: %s" sprint-name))))

(defvar org-jira-team-members
  '(("dhaley"    . "Damon")
    ("dwhitesi"  . "Whiteside")
    ("mbartlet"  . "Michael")
    ("sbhatkar"  . "Swapnil")
    ("aliao"     . "Anna")
    ("drager"    . "Rager")
    ("avillarr"  . "Andres")
    ("dhorton"   . "Dan Horton"))
  "Alist of (username . display-name) for team members.")

(defun org-jira-set-priority ()
  "Set priority of the issue at point with completion, updating Jira and org."
  (interactive)
  (require 'org-jira)
  (let* ((issue-id (org-entry-get nil "ID"))
         (priorities (jiralib-get-priorities))
         (names (mapcar #'cdr priorities))
         (choice (completing-read "Priority: " names nil t))
         (priority-id (car (rassoc choice priorities)))
         (org-cookie (cdr (assoc choice org-jira-priority-to-org-priority-alist))))
    (unless issue-id (error "No issue at point"))
    (jiralib-update-issue issue-id `((priority (id . ,priority-id))))
    (org-entry-put nil "priority" choice)
    (when org-cookie
      (save-excursion
        (org-back-to-heading t)
        (org-priority org-cookie)))
    (message "Set %s priority to %s" issue-id choice)))

(defun org-jira-set-assignee ()
  "Change the assignee of the issue at point with completion."
  (interactive)
  (require 'org-jira)
  (let* ((issue-id (org-entry-get nil "ID"))
         (project (replace-regexp-in-string "-[0-9]+" "" issue-id))
         (users (org-jira-get-assignable-users project))
         (user (completing-read "Assignee: " (mapcar #'car users) nil t))
         (username (cdr (assoc user users))))
    (jiralib-update-issue issue-id `((assignee (name . ,username))))
    (org-entry-put nil "assignee" user)
    (message "Assigned %s to %s" issue-id user)))

(defun org-jira-set-sprint ()
  "Change the sprint of the issue at point with completion."
  (interactive)
  (require 'org-jira)
  (let* ((issue-id (org-entry-get nil "ID"))
         (boards (jiralib--rest-call-it
                  "/rest/agile/1.0/board?projectKeyOrId=CO&type=scrum" :type "GET"))
         (board-id (cdr (assoc 'id (aref (cdr (assoc 'values boards)) 0))))
         (sprints-data (jiralib--rest-call-it
                        (format "/rest/agile/1.0/board/%s/sprint?state=active,future" board-id)
                        :type "GET"))
         (sprints (append (cdr (assoc 'values sprints-data)) nil))
         (names (mapcar (lambda (s) (cdr (assoc 'name s))) sprints))
         (choice (completing-read "Sprint: " names nil t))
         (sprint (seq-find (lambda (s) (string= (cdr (assoc 'name s)) choice)) sprints))
         (sprint-id (cdr (assoc 'id sprint))))
    (jiralib-update-issue issue-id `((customfield_10005 . ,sprint-id)))
    (org-entry-put nil "sprint" choice)
    ;; Update ACTIVE tag: add if moving to active sprint, remove otherwise
    (let* ((active-data (jiralib--rest-call-it
                         (format "/rest/agile/1.0/board/%s/sprint?state=active" board-id)
                         :type "GET"))
           (active-names (mapcar (lambda (s) (cdr (assoc 'name s)))
                                 (append (cdr (assoc 'values active-data)) nil))))
      (if (member choice active-names)
          (org-toggle-tag "ACTIVE" 'on)
        (org-toggle-tag "ACTIVE" 'off)))
    (message "Moved %s to %s" issue-id choice)))

(defun org-jira-update-story-points ()
  "Update story points for the issue at point from the org property."
  (interactive)
  (require 'org-jira)
  (let* ((issue-id (org-entry-get nil "ID"))
         (sp (org-entry-get nil "story-points")))
    (unless issue-id (error "No issue at point"))
    (unless sp (error "No story-points property"))
    (jiralib-update-issue issue-id
                          `((customfield_10002 . ,(string-to-number sp))))
    (message "Updated %s story points to %s" issue-id sp)))

(defun org-jira-update-epic-link ()
  "Update epic link for the issue at point from the org property."
  (interactive)
  (require 'org-jira)
  (let* ((issue-id (org-entry-get nil "ID"))
         (epic (org-entry-get nil "epic")))
    (unless issue-id (error "No issue at point"))
    (unless epic (error "No epic property"))
    (jiralib-update-issue issue-id
                          `((customfield_10006 . ,epic)))
    (message "Updated %s epic link to %s" issue-id epic)))

(defun org-jira-set-epic ()
  "Set the epic of the issue or heading at point with completion."
  (interactive)
  (require 'org-jira)
  (let* ((epics-raw (jiralib-do-jql-search
                     "project = CO AND issuetype = Epic ORDER BY updated DESC"
                     200))
         (epics (mapcar (lambda (e)
                          (let* ((key (cdr (assoc 'key e)))
                                 (fields (cdr (assoc 'fields e)))
                                 (name (or (cdr (assoc 'customfield_10007 fields))
                                           (cdr (assoc 'summary fields))
                                           key)))
                            (cons (format "%s — %s" name key) key)))
                        epics-raw))
         (choice (completing-read "Epic: " (mapcar #'car epics) nil t))
         (epic-key (cdr (assoc choice epics)))
         (epic-name (car (split-string choice " — ")))
         (issue-id (org-entry-get nil "ID")))
    ;; Update org properties
    (org-entry-put nil "jira-epic" epic-name)
    (org-entry-put nil "epic" epic-key)
    (org-entry-put nil "epic-name" epic-name)
    ;; Push to Jira if this is a synced issue
    (when (and issue-id (string-match-p "\\`[A-Z]+-[0-9]+\\'" issue-id))
      (jiralib-update-issue issue-id `((customfield_10006 . ,epic-key)))
      (message "Set %s epic to %s (%s)" issue-id epic-name epic-key))
    (unless (and issue-id (string-match-p "\\`[A-Z]+-[0-9]+\\'" issue-id))
      (message "Set epic to %s (%s) — will be applied on create" epic-name epic-key))))

(defun org-jira-move-to-backlog ()
  "Remove the issue at point from its sprint (move to backlog)."
  (interactive)
  (require 'org-jira)
  (let* ((issue-id (org-entry-get nil "ID"))
         (sprint-str (org-entry-get nil "sprint")))
    (unless issue-id (error "No issue at point"))
    (unless sprint-str (message "Already in backlog"))
    (when sprint-str
      ;; Find the sprint ID to remove from
      (let* ((boards (jiralib--rest-call-it
                      "/rest/agile/1.0/board?projectKeyOrId=CO&type=scrum" :type "GET"))
             (board-id (cdr (assoc 'id (aref (cdr (assoc 'values boards)) 0)))))
        (jiralib--rest-call-it
         (format "/rest/agile/1.0/backlog" )
         :type "POST"
         :data (json-encode `((issues . [,issue-id]))))
        (org-entry-delete nil "sprint")
        (message "Moved %s to backlog" issue-id)))))

(defun org-jira-sync-team-member (username)
  "Sync issues for a team member by USERNAME into ~/.org-jira/co-USERNAME.org."
  (interactive
   (list (completing-read "Team member: "
                          (mapcar #'car org-jira-team-members) nil t)))
  (require 'org-jira)
  (let ((org-jira-custom-jqls
         `((:jql ,(format "project = CO AND assignee = %s AND statusCategory != Done ORDER BY updated DESC" username)
                 :limit 50
                 :filename ,(format "co-%s" username)))))
    (org-jira-get-issues-from-custom-jql)))

(defun org-jira-sync-current-sprint ()
  "Sync all issues in the current sprint."
  (interactive)
  (require 'org-jira)
  (let ((org-jira-custom-jqls
         '((:jql "project = CO AND statusCategory != Done AND sprint IN openSprints() ORDER BY priority DESC"
                 :limit 100
                 :filename "co-current-sprint"))))
    (org-jira-get-issues-from-custom-jql)))

(defun org-jira-sync-deputies ()
  "Sync all issues for deputy team members."
  (interactive)
  (require 'org-jira)
  (let ((org-jira-custom-jqls
         '((:jql "project = CO AND statusCategory != Done AND (assignee = jgu2 OR assignee = nguba OR assignee = sclark OR assignee = jjenkins OR assignee = rhurst OR assignee = rolson2 OR assignee = pedwards OR assignee = jhuggins) ORDER BY assignee, updated DESC"
                 :limit 100
                 :filename "co-deputies"))))
    (org-jira-get-issues-from-custom-jql)))

(defun org-jira-create-from-heading ()
  "Create a Jira issue from the org heading at point.
Reads jira-* properties and pushes to Jira. Only sends non-empty optional fields.
After creation, run `org-jira-get-issues-from-custom-jql' to pull the
canonical copy into ~/.org-jira/ for full org-jira management."
  (interactive)
  (require 'org-jira)
  (let* ((project (or (org-entry-get nil "jira-project") "CO"))
         (type (or (org-entry-get nil "jira-type") "Task"))
         (priority-name (or (org-entry-get nil "jira-priority") "Major"))
         (assignee (org-entry-get nil "jira-assignee"))
         (epic (or (org-entry-get nil "jira-epic") "OPS INT - Misc"))
         (component (org-entry-get nil "jira-component"))
         (labels-str (org-entry-get nil "jira-labels"))
         (sprint (org-entry-get nil "jira-sprint"))
         (story-points (org-entry-get nil "jira-story-points"))
         (due-date (org-entry-get nil "jira-due-date"))
         (servicenow-link (org-entry-get nil "jira-servicenow-link"))
         (task-number (org-entry-get nil "jira-task-number"))
         (contact-email (org-entry-get nil "jira-contact-email"))
         (fix-version (org-entry-get nil "jira-fix-version"))
         (summary (substring-no-properties (org-get-heading t t t t)))
         (description (save-excursion
                        (org-back-to-heading t)
                        (let ((end (org-entry-end-position)))
                          (forward-line)
                          (while (looking-at "^\\(SCHEDULED\\|DEADLINE\\|CLOSED\\|CLOCK\\):")
                            (forward-line))
                          (when (looking-at ":PROPERTIES:")
                            (re-search-forward ":END:" nil t)
                            (forward-line))
                          (string-trim
                           (buffer-substring-no-properties (point) end)))))
         (priority-id (car (rassoc priority-name (jiralib-get-priorities))))
         (type-id (car (rassoc type (jiralib-get-issue-types-by-project project))))
         (fields `((project (key . ,project))
                   (issuetype (id . ,type-id))
                   (summary . ,summary)
                   (priority (id . ,priority-id)))))
    (when (and description (not (string-empty-p description)))
      (push `(description . ,description) fields))
    (when (and assignee (not (string-empty-p assignee)))
      (push `(assignee (name . ,assignee)) fields))
    (when (and epic (not (string-empty-p epic)))
      (let ((epic-key (if (string-match-p "\\`[A-Z]+-[0-9]+\\'" epic)
                          epic
                        (org-jira--resolve-epic-key project epic))))
        (push `(customfield_10006 . ,epic-key) fields)))
    (when (and component (not (string-empty-p component)))
      (push `(components . [((name . ,component))]) fields))
    (when (and labels-str (not (string-empty-p labels-str)))
      (push `(labels . ,(vconcat (split-string labels-str "," t "\\s-*"))) fields))
    (when (and sprint (not (string-empty-p sprint)))
      (let ((sprint-id (if (string-match-p "\\`[0-9]+\\'" sprint)
                           (string-to-number sprint)
                         (org-jira--resolve-sprint-id project sprint))))
        (push `(customfield_10005 . ,sprint-id) fields)))
    (when (and story-points (not (string-empty-p story-points)))
      (push `(customfield_10002 . ,(string-to-number story-points)) fields))
    (when (and due-date (not (string-empty-p due-date)))
      (push `(duedate . ,due-date) fields))
    (when (and servicenow-link (not (string-empty-p servicenow-link)))
      (push `(customfield_11400 . ,servicenow-link) fields))
    (when (and task-number (not (string-empty-p task-number)))
      (push `(customfield_10902 . ,task-number) fields))
    (when (and contact-email (not (string-empty-p contact-email)))
      (push `(customfield_12000 . ,contact-email) fields))
    (when (and fix-version (not (string-empty-p fix-version)))
      (push `(fixVersions . [((name . ,fix-version))]) fields))
    (let* ((ticket `((fields . ,fields)))
           (result (jiralib-create-issue ticket))
           (key (cdr (assoc 'key result)))
           (url (format "%s/browse/%s" jiralib-url key)))
      (org-set-property "Jira" key)
      ;; Auto-add watchers for break-fix issues
      (let ((watchers (or (org-entry-get nil "jira-watchers")
                          (when (and labels-str (string-match-p "break-fix" labels-str))
                            "dhorton"))))
        (when watchers
          (dolist (user (split-string watchers "," t "\\s-*"))
            (condition-case nil
                (jiralib--rest-call-it
                 (format "/rest/api/2/issue/%s/watchers" key)
                 :type "POST"
                 :data (json-encode user))
              (error nil))
            (message "Added watcher %s to %s" user key))))
      (kill-new url)
      (browse-url url)
      (message "Created Jira issue: %s (URL copied)" key))))

(defun org-jira-add-watcher ()
  "Add a watcher to the Jira issue at point with completion."
  (interactive)
  (require 'org-jira)
  (let* ((jira-key (org-entry-get nil "Jira"))
         (id (org-entry-get nil "ID"))
         (issue-id (or jira-key
                       (when (and id (string-match-p "\\`[A-Z]+-[0-9]+\\'" id)) id)))
         (users (org-jira-get-assignable-users "CO"))
         (user (completing-read "Add watcher: " (mapcar #'car users) nil t))
         (username (cdr (assoc user users))))
    (unless issue-id (error "No Jira issue at point"))
    (jiralib--rest-call-it
     (format "/rest/api/2/issue/%s/watchers" issue-id)
     :type "POST"
     :data (json-encode username))
    (message "Added %s as watcher on %s" user issue-id)))

(defun org-jira-sprint-report ()
  "Generate a sprint report for the current active StratusOps sprint.
Shows closed issues, open/carried-over issues, and story point totals."
  (interactive)
  (require 'org-jira)
  (let* ((boards (jiralib--rest-call-it
                  "/rest/agile/1.0/board?projectKeyOrId=CO&type=scrum" :type "GET"))
         (board-id (cdr (assoc 'id (aref (cdr (assoc 'values boards)) 0))))
         (active (jiralib--rest-call-it
                  (format "/rest/agile/1.0/board/%s/sprint?state=active" board-id)
                  :type "GET"))
         (sprint (seq-find (lambda (s) (string-match-p "StratusOps" (cdr (assoc 'name s))))
                           (append (cdr (assoc 'values active)) nil)))
         (sprint-name (cdr (assoc 'name sprint)))
         (sprint-id (cdr (assoc 'id sprint)))
         ;; Closed issues in this sprint
         (closed (jiralib-do-jql-search
                  (format "project = CO AND sprint = %d AND assignee = dhaley AND status IN (Done, Closed) ORDER BY updated DESC"
                          sprint-id)
                  50))
         ;; Open issues still in this sprint
         (open (jiralib-do-jql-search
                (format "project = CO AND sprint = %d AND assignee = dhaley AND statusCategory != Done ORDER BY priority DESC"
                        sprint-id)
                50))
         (buf (get-buffer-create "*Sprint Report*")))
    (with-current-buffer buf
      (erase-buffer)
      (org-mode)
      (insert (format "#+TITLE: Sprint Report — %s\n" sprint-name))
      (insert (format "#+DATE: %s\n\n" (format-time-string "%Y-%m-%d %A")))
      ;; Summary
      (let ((closed-pts (cl-reduce #'+ (mapcar (lambda (i)
                                                  (or (cdr (assoc 'customfield_10002
                                                                  (cdr (assoc 'fields i)))) 0))
                                                closed)
                                   :initial-value 0))
            (open-pts (cl-reduce #'+ (mapcar (lambda (i)
                                               (or (cdr (assoc 'customfield_10002
                                                               (cdr (assoc 'fields i)))) 0))
                                             open)
                                :initial-value 0)))
        (insert "* Summary\n")
        (insert (format "- Completed: %d issues (%g story points)\n" (length closed) closed-pts))
        (insert (format "- Remaining: %d issues (%g story points)\n" (length open) open-pts))
        (insert (format "- Total: %d issues (%g story points)\n\n"
                        (+ (length closed) (length open))
                        (+ closed-pts open-pts))))
      ;; Closed
      (insert "* Completed\n")
      (if (null closed)
          (insert "  /None/\n")
        (dolist (issue closed)
          (let* ((fields (cdr (assoc 'fields issue)))
                 (key (cdr (assoc 'key issue)))
                 (summary (cdr (assoc 'summary fields)))
                 (pts (or (cdr (assoc 'customfield_10002 fields)) 0))
                 (status (cdr (assoc 'name (cdr (assoc 'status fields))))))
            (insert (format "** DONE [[%s/browse/%s][%s]] %s\n" jiralib-url key key summary))
            (insert (format "   - Status: %s | Points: %g\n" status pts)))))
      (insert "\n")
      ;; Open / Carry-over
      (insert "* Remaining / Carry-over\n")
      (if (null open)
          (insert "  /None — all work completed!/\n")
        (dolist (issue open)
          (let* ((fields (cdr (assoc 'fields issue)))
                 (key (cdr (assoc 'key issue)))
                 (summary (cdr (assoc 'summary fields)))
                 (pts (or (cdr (assoc 'customfield_10002 fields)) 0))
                 (status (cdr (assoc 'name (cdr (assoc 'status fields))))))
            (insert (format "** TODO [[%s/browse/%s][%s]] %s\n" jiralib-url key key summary))
            (insert (format "   - Status: %s | Points: %g\n" status pts))))))
    (switch-to-buffer buf)
    (goto-char (point-min))
    (message "Sprint report generated for %s" sprint-name)))

;;; ── C-c C-c to push all changes to Jira ──

(defun my/org-jira-in-jira-buffer-p ()
  "Return non-nil if current buffer has org-jira-mode."
  (bound-and-true-p org-jira-mode))

(defun org-jira-push-heading ()
  "Push all Jira-relevant property changes from heading at point to Jira."
  (interactive)
  (require 'org-jira)
  (let* ((issue-id (org-entry-get nil "ID"))
         (summary (org-get-heading t t t t))
         (fields '())
         (changes '()))
    (unless (and issue-id (string-match-p "^[A-Z]+-[0-9]+$" issue-id))
      (error "Not on a Jira issue heading"))
    ;; Story points
    (let ((sp (org-entry-get nil "story-points")))
      (when (and sp (not (string-empty-p sp)))
        (push `(customfield_10002 . ,(string-to-number sp)) fields)
        (push (format "  story-points: %s" sp) changes)))
    ;; Priority
    (let* ((pri-name (org-entry-get nil "priority"))
           (pri-id (and pri-name (not (string-empty-p pri-name))
                        (car (rassoc pri-name (jiralib-get-priorities))))))
      (when pri-id
        (push `(priority (id . ,pri-id)) fields)
        (push (format "  priority: %s" pri-name) changes)))
    ;; Assignee — only push if we can resolve to a username
    (let ((assignee (org-entry-get nil "assignee")))
      (when (and assignee (not (string-empty-p assignee))
                 (not (string= assignee "Unassigned")))
        (let* ((project (replace-regexp-in-string "-[0-9]+" "" issue-id))
               (users (org-jira-get-assignable-users project))
               (username (cdr (assoc assignee users))))
          (if username
              (progn
                (push `(assignee (name . ,username)) fields)
                (push (format "  assignee: %s (%s)" assignee username) changes))
            (message "Warning: could not resolve assignee '%s' — skipping" assignee)))))
    ;; Epic link
    (let ((epic (org-entry-get nil "epic")))
      (when (and epic (not (string-empty-p epic)))
        (push `(customfield_10006 . ,epic) fields)
        (push (format "  epic: %s" epic) changes)))
    ;; Components
    (let ((components (org-entry-get nil "components")))
      (when (and components (not (string-empty-p components)))
        (push `(components . ,(vconcat (mapcar (lambda (c) `((name . ,(string-trim c))))
                                               (split-string components "," t)))) fields)
        (push (format "  components: %s" components) changes)))
    ;; Labels
    (let ((labels (org-entry-get nil "labels")))
      (when (and labels (not (string-empty-p labels)))
        (push `(labels . ,(vconcat (split-string labels "," t "\\s-*"))) fields)
        (push (format "  labels: %s" labels) changes)))
    ;; ServiceNow Ticket Link
    (let ((snow (org-entry-get nil "servicenow-link")))
      (when (and snow (not (string-empty-p snow)))
        (push `(customfield_11400 . ,snow) fields)
        (push (format "  servicenow-link: %s" snow) changes)))
    ;; Sprint
    (let ((sprint (org-entry-get nil "sprint")))
      (when (and sprint (not (string-empty-p sprint)))
        (condition-case nil
            (let ((sprint-id (org-jira--resolve-sprint-id
                              (replace-regexp-in-string "-[0-9]+" "" issue-id) sprint)))
              (push `(customfield_10005 . ,sprint-id) fields)
              (push (format "  sprint: %s" sprint) changes))
          (error nil))))
    (if (null fields)
        (message "No fields to push for %s" issue-id)
      ;; Show changes and confirm
      (let ((msg (format "Push to %s (%s)?\n\nFields:\n%s"
                         issue-id summary
                         (string-join (nreverse changes) "\n"))))
        (when (y-or-n-p msg)
          (jiralib-update-issue issue-id fields)
          (message "Pushed %d fields to %s" (length fields) issue-id))))))

(defun my/org-jira-ctrl-c-ctrl-c (&optional orig-fn &rest args)
  "If on a Jira heading, push changes. Otherwise run normal C-c C-c."
  (if (and (my/org-jira-in-jira-buffer-p)
           (org-entry-get nil "ID")
           (string-match-p "^[A-Z]+-[0-9]+$" (or (org-entry-get nil "ID") "")))
      (org-jira-push-heading)
    (when orig-fn (apply orig-fn args))))

;;; ── org-shiftup/down priority sync for org-jira buffers ──

(defvar my/org-jira-org-to-jira-priority-alist
  '((?A . "Blocker")
    (?B . "Major")
    (?C . "Minor"))
  "Reverse mapping from org priority cookie to Jira priority name.")

(defun my/org-jira-after-priority-change (&rest _)
  "After org priority change, sync to Jira if in an org-jira buffer."
  (when (my/org-jira-in-jira-buffer-p)
    (let* ((issue-id (org-entry-get nil "ID"))
           (pri-char (save-excursion
                       (org-back-to-heading t)
                       (when (looking-at org-heading-regexp)
                         (org-get-priority (match-string 0)))))
           (pri-letter (cond ((null pri-char) nil)
                             ((>= pri-char (* 1000 (- org-priority-lowest org-priority-highest -1))) ?A)
                             ((<= pri-char 1000) ?C)
                             (t ?B)))
           (jira-name (and pri-letter (cdr (assoc pri-letter my/org-jira-org-to-jira-priority-alist))))
           (pri-id (and jira-name (car (rassoc jira-name (jiralib-get-priorities))))))
      (when (and issue-id pri-id (string-match-p "^[A-Z]+-[0-9]+$" issue-id))
        (condition-case err
            (progn
              (jiralib-update-issue issue-id `((priority (id . ,pri-id))))
              (org-entry-put nil "priority" jira-name)
              (message "Updated %s priority to %s" issue-id jira-name))
          (error (message "Failed to sync priority: %s" (error-message-string err))))))))

(advice-add 'org-priority-up :after #'my/org-jira-after-priority-change)
(advice-add 'org-priority-down :after #'my/org-jira-after-priority-change)

;; Hook C-c C-c to push Jira changes in org-jira buffers
;; Hook C-c C-t to use org-jira-progress-issue for status transitions
(defun my/org-jira-progress-issue-safe ()
  "Progress issue with confirmation."
  (interactive)
  (let* ((issue-id (org-entry-get nil "ID"))
         (summary (org-get-heading t t t t))
         (status (org-entry-get nil "status")))
    (if (and issue-id (string-match-p "^[A-Z]+-[0-9]+$" issue-id))
        (when (y-or-n-p (format "Transition %s (%s) [status: %s]? " issue-id summary status))
          (org-jira-progress-issue))
      ;; Not on a Jira issue, run normal org-todo
      (org-todo))))
(defun my/org-jira-ctrl-c-ctrl-c-hook ()
  "In org-jira buffers, override C-c C-c and C-c C-t."
  (when (bound-and-true-p org-jira-mode)
    (local-set-key (kbd "C-c C-c") #'org-jira-push-heading)
    (local-set-key (kbd "C-c C-t") #'my/org-jira-progress-issue-safe)))
(add-hook 'org-jira-mode-hook #'my/org-jira-ctrl-c-ctrl-c-hook)

;;; ── Cycle through team agendas with ] and [ ──

(defvar my/org-jira-agenda-keys
  '("jd" "jw" "jm" "jn" "ja" "jr" "jv" "jh")
  "Agenda dispatch keys for team members in cycle order.")

(defvar my/org-jira-agenda-index 0
  "Current index in the team agenda cycle.")

(defun my/org-jira-cycle-team-agenda (&optional backward)
  "Cycle to the next team member's Jira agenda. With prefix arg, go backward."
  (interactive "P")
  (let* ((len (length my/org-jira-agenda-keys))
         (delta (if backward -1 1))
         (idx (mod (+ my/org-jira-agenda-index delta) len))
         (key (nth idx my/org-jira-agenda-keys)))
    (setq my/org-jira-agenda-index idx)
    (org-agenda nil key)))

(defun my/org-jira-cycle-team-agenda-backward ()
  "Cycle to the previous team member's Jira agenda."
  (interactive)
  (my/org-jira-cycle-team-agenda t))

(with-eval-after-load 'org-agenda
  (define-key org-agenda-mode-map (kbd "]") #'my/org-jira-cycle-team-agenda)
  (define-key org-agenda-mode-map (kbd "[") #'my/org-jira-cycle-team-agenda-backward))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c j c") #'org-jira-create-from-heading)
  (define-key org-mode-map (kbd "C-c j C") (lambda () (interactive)
                                              (require 'org-jira)
                                              (org-jira-update-comments-for-current-issue)
                                              (message "Comments updated")))
  (define-key org-mode-map (kbd "C-c j m") #'org-jira-sync-team-member)
  (define-key org-mode-map (kbd "C-c j s") #'org-jira-sync-current-sprint)
  (define-key org-mode-map (kbd "C-c j b") #'org-jira-move-to-backlog)
  (define-key org-mode-map (kbd "C-c j p") #'org-jira-progress-issue)
  (define-key org-mode-map (kbd "C-c j a") #'org-jira-set-assignee)
  (define-key org-mode-map (kbd "C-c j S") #'org-jira-set-sprint)
  (define-key org-mode-map (kbd "C-c j P") #'org-jira-set-priority)
  (define-key org-mode-map (kbd "C-c j e") #'org-jira-enrich-buffer)
  (define-key org-mode-map (kbd "C-c j E") #'org-jira-set-epic)
  (define-key org-mode-map (kbd "C-c j w") #'org-jira-add-watcher)
  (define-key org-mode-map (kbd "C-c j u") #'org-jira-push-heading))

(provide 'dot-org-jira)

;;; dot-org-jira.el ends here

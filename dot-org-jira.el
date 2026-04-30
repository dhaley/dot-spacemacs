;;; dot-org-jira.el --- org-jira configuration for Jira Server -*- lexical-binding: t -*-

;;; Commentary:
;; Customizations for org-jira against Jira Server (API v2).
;; Includes: PAT auth, Jira Server field patches, org-capture integration.

;;; Code:

(require 'seq)

(use-package org-jira
  :defer t
  :commands (org-jira-get-issues org-jira-get-issues-from-custom-jql
             org-jira-create-issue org-jira-browse-issue)
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
        '((:jql "project = CO AND assignee = dhaley AND status NOT IN (Done, Closed) ORDER BY updated DESC"
                :limit 50
                :filename "co-my-issues")
          (:jql "project = CO AND status NOT IN (Done, Closed) AND sprint IN openSprints() ORDER BY priority DESC"
                :limit 50
                :filename "co-current-sprint")))

  (setq org-jira-default-jql "project = CO AND assignee = dhaley AND status NOT IN (Done, Closed) ORDER BY updated DESC"))

;;; ── Create Jira issues from org headings ──

(defun org-jira--last-business-day-next-month ()
  "Return the last business day (Mon-Fri) of next month as yyyy-MM-dd."
  (let* ((now (decode-time))
         (month (nth 4 now))
         (year (nth 5 now))
         ;; advance to next month
         (next-month (if (= month 12) 1 (1+ month)))
         (next-year (if (= month 12) (1+ year) year))
         ;; last day of next month = day 0 of month after that
         (after-month (if (= next-month 12) 1 (1+ next-month)))
         (after-year (if (= next-month 12) (1+ next-year) next-year))
         (last-day (nth 3 (decode-time (encode-time 0 0 0 0 after-month after-year))))
         (last-time (encode-time 0 0 12 last-day next-month next-year))
         (dow (nth 6 (decode-time last-time))))
    ;; Roll back from weekend: 0=Sun->-2, 6=Sat->-1
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
             ;; Get active sprints
             (active (jiralib--rest-call-it
                      (format "/rest/agile/1.0/board/%s/sprint?state=active" board-id)
                      :type "GET"))
             (active-list (append (cdr (assoc 'values active)) nil))
             ;; Find the StratusOps sprint
             (current (seq-find (lambda (s) (string-match-p "StratusOps Sprint" (cdr (assoc 'name s))))
                                active-list))
             ;; Get future sprints
             (future (jiralib--rest-call-it
                      (format "/rest/agile/1.0/board/%s/sprint?state=future" board-id)
                      :type "GET"))
             (future-list (append (cdr (assoc 'values future)) nil))
             (next (seq-find (lambda (s) (string-match-p "StratusOps Sprint" (cdr (assoc 'name s))))
                             future-list)))
        (cond
         (next (cdr (assoc 'name next)))
         ;; Fallback: increment current sprint number
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

(defun org-jira-create-from-heading ()
  "Create a Jira issue from the org heading at point.
Reads jira-* properties and pushes to Jira. Only sends non-empty optional fields."
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
    ;; Epic Link — resolve name to key if not already a key
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
    ;; Story Points
    (when (and story-points (not (string-empty-p story-points)))
      (push `(customfield_10002 . ,(string-to-number story-points)) fields))
    ;; Due Date (format: d/MMM/yy or yyyy-MM-dd)
    (when (and due-date (not (string-empty-p due-date)))
      (push `(duedate . ,due-date) fields))
    ;; ServiceNow Ticket Link
    (when (and servicenow-link (not (string-empty-p servicenow-link)))
      (push `(customfield_11400 . ,servicenow-link) fields))
    ;; Task Number
    (when (and task-number (not (string-empty-p task-number)))
      (push `(customfield_10902 . ,task-number) fields))
    ;; Point of Contact Email
    (when (and contact-email (not (string-empty-p contact-email)))
      (push `(customfield_12000 . ,contact-email) fields))
    ;; Fix Version/s
    (when (and fix-version (not (string-empty-p fix-version)))
      (push `(fixVersions . [((name . ,fix-version))]) fields))
    (let* ((ticket `((fields . ,fields)))
           (result (jiralib-create-issue ticket))
           (key (cdr (assoc 'key result)))
           (url (format "%s/browse/%s" jiralib-url key)))
      (org-set-property "Jira" key)
      (kill-new url)
      (browse-url url)
      (message "Created Jira issue: %s (URL copied)" key))))

(defun org-jira-sync-from-heading ()
  "Sync the org heading at point from its linked Jira issue.
Updates TODO state and assignee based on current Jira status."
  (interactive)
  (require 'org-jira)
  (let ((key (org-entry-get nil "Jira")))
    (unless key (error "No :Jira: property on this heading"))
    (let* ((issue (car (jiralib-do-jql-search (format "key = %s" key) 1)))
           (fields (cdr (assoc 'fields issue)))
           (status-name (cdr (assoc 'name (cdr (assoc 'status fields)))))
           (assignee-name (cdr (assoc 'name (cdr (assoc 'assignee fields)))))
           (org-keyword (org-jira-get-org-keyword-from-status status-name)))
      (when assignee-name
        (org-entry-put nil "jira-assignee" assignee-name))
      (org-entry-put nil "jira-status" status-name)
      (when org-keyword
        (org-todo org-keyword))
      (message "Synced %s: %s (%s)" key status-name (or assignee-name "unassigned")))))

(defun org-jira-sync-buffer ()
  "Sync all org headings with a :Jira: property in the current buffer."
  (interactive)
  (require 'org-jira)
  (let ((count 0))
    (org-map-entries
     (lambda ()
       (when (org-entry-get nil "Jira")
         (condition-case err
             (progn (org-jira-sync-from-heading)
                    (setq count (1+ count)))
           (error (message "Error syncing %s: %s"
                           (org-entry-get nil "Jira")
                           (error-message-string err))))))
     nil 'file)
    (message "Synced %d Jira issues" count)))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c j c") #'org-jira-create-from-heading)
  (define-key org-mode-map (kbd "C-c j s") #'org-jira-sync-from-heading)
  (define-key org-mode-map (kbd "C-c j S") #'org-jira-sync-buffer))

(provide 'dot-org-jira)

;;; dot-org-jira.el ends here

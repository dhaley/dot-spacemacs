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

  ;; Map Jira priorities to org priority cookies so org-agenda doesn't choke
  (setq org-jira-priority-to-org-priority-alist
        '(("Blocker"  . ?A)
          ("Critical" . ?A)
          ("Major"    . ?B)
          ("Minor"    . ?C)
          ("Trivial"  . ?C)))
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
        '(;; ── My issues (in org-agenda by default) ──
          (:jql "project = CO AND assignee = dhaley AND status NOT IN (Done, Closed) ORDER BY updated DESC"
                :limit 50
                :filename "co-dhaley")
          ;; ── Team members (not in org-agenda, use agenda filters to view) ──
          (:jql "project = CO AND assignee = dwhitesi AND status NOT IN (Done, Closed) ORDER BY updated DESC"
                :limit 50
                :filename "co-dwhitesi")
          (:jql "project = CO AND assignee = mswapnil AND status NOT IN (Done, Closed) ORDER BY updated DESC"
                :limit 50
                :filename "co-mswapnil")
          (:jql "project = CO AND assignee = aliao AND status NOT IN (Done, Closed) ORDER BY updated DESC"
                :limit 50
                :filename "co-aliao")
          (:jql "project = CO AND assignee = drager AND status NOT IN (Done, Closed) ORDER BY updated DESC"
                :limit 50
                :filename "co-drager")
          (:jql "project = CO AND assignee = avillarr AND status NOT IN (Done, Closed) ORDER BY updated DESC"
                :limit 50
                :filename "co-avillarr")
          (:jql "project = CO AND assignee = dhorton AND status NOT IN (Done, Closed) ORDER BY updated DESC"
                :limit 50
                :filename "co-dhorton")
          ;; ── Current sprint (all team, for sprint review) ──
          (:jql "project = CO AND status NOT IN (Done, Closed) AND sprint IN openSprints() ORDER BY priority DESC"
                :limit 100
                :filename "co-current-sprint")))

  (setq org-jira-default-jql "project = CO AND assignee = dhaley AND status NOT IN (Done, Closed) ORDER BY updated DESC"))

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
      (kill-new url)
      (browse-url url)
      (message "Created Jira issue: %s (URL copied)" key))))

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
                (format "project = CO AND sprint = %d AND assignee = dhaley AND status NOT IN (Done, Closed) ORDER BY priority DESC"
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

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c j c") #'org-jira-create-from-heading))

(provide 'dot-org-jira)

;;; dot-org-jira.el ends here

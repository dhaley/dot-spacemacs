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
  ;; Jira Server uses REST API v2, not v3 (Cloud)
  (setq jiralib-target-api-version 2)
  ;; Jira Server uses "name" for assignee, not "accountId" (Cloud)
  (setq org-jira-users '(("Unassigned" . nil)))
  (make-directory "~/.org-jira" t)
  (setq org-jira-working-dir "~/.org-jira")
  ;; Bearer PAT auth for Jira Server (reads token from authinfo)
  (setq jiralib-token
        (cons "Authorization"
              (concat "Bearer "
                      (string-trim
                       (shell-command-to-string
                        "/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:JIRA_TOKEN' ~/Library/LaunchAgents/mcp-jira.plist")))))
  :config
  ;; Jira Server doesn't have /rest/api/2/label endpoint (Cloud-only).
  ;; Fetch labels from existing project issues instead.
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

  (defun org-jira--resolve-sprint-id (project sprint-name)
    "Look up the numeric sprint ID for SPRINT-NAME in PROJECT's scrum board."
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
    (let* ((project (or (org-entry-get nil "jira-project") "CO"))
           (type (or (org-entry-get nil "jira-type") "Task"))
           (priority-name (or (org-entry-get nil "jira-priority") "Major"))
           (assignee (org-entry-get nil "jira-assignee"))
           (epic (org-entry-get nil "jira-epic"))
           (component (org-entry-get nil "jira-component"))
           (labels-str (org-entry-get nil "jira-labels"))
           (sprint (org-entry-get nil "jira-sprint"))
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
        (push `(customfield_10006 . ,epic) fields))
      (when (and component (not (string-empty-p component)))
        (push `(components . [((name . ,component))]) fields))
      (when (and labels-str (not (string-empty-p labels-str)))
        (push `(labels . ,(vconcat (split-string labels-str "," t "\\s-*"))) fields))
      (when (and sprint (not (string-empty-p sprint)))
        (let ((sprint-id (if (string-match-p "\\`[0-9]+\\'" sprint)
                             (string-to-number sprint)
                           (org-jira--resolve-sprint-id project sprint))))
          (push `(customfield_10005 . ,sprint-id) fields)))
      (let* ((ticket `((fields . ,fields)))
             (result (jiralib-create-issue ticket))
             (key (cdr (assoc 'key result))))
        (org-set-property "Jira" key)
        (message "Created Jira issue: %s" key))))

  (setq org-jira-default-jql "project = CO AND assignee = dhaley AND status NOT IN (Done, Closed) ORDER BY updated DESC"))

(provide 'dot-org-jira)

;;; dot-org-jira.el ends here

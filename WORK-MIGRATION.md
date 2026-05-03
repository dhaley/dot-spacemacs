# Work Machine Migration Guide

Steps needed to bring the work machine's `~/.local/emacs/work.el` in line with
the current standard: machine-specific config lives in `~/.local/emacs/`, not
in `.spacemacs`.

## Standard

`.spacemacs` contains only values that are correct on **every** machine.
Machine-specific values go in `~/.local/emacs/<machine>.el` and are set via
`emacs-startup-hook` so they run after `custom-set-variables`.

## Steps

### 1. Add `org-directory` to `work.el`

`org-directory` was removed from `custom-set-variables` in `.spacemacs`.
Add this to `~/.local/emacs/work.el` inside the `emacs-startup-hook` lambda
(alongside the other org path settings that should already be there):

```elisp
(setq org-directory "~/Box/projects")
```

If `work.el` does not yet have an `emacs-startup-hook` block, add one using
`home.el.template` as a model, adjusting paths for the work machine:

```elisp
(setq my/org-base-dir (expand-file-name "~/Box/projects"))
(setq diary-file (expand-file-name "diary.org" my/org-base-dir))

(add-hook 'emacs-startup-hook
          (lambda ()
            (let ((base my/org-base-dir))
              (make-directory base t)
              (setq org-directory base)
              (setq org-agenda-diary-file (expand-file-name "diary.org" base))
              (setq org-agenda-files (list (expand-file-name "todo.txt" base)))
              (setq org-default-notes-file (expand-file-name "todo.txt" base)))))
```

### 2. Move `cloudwatch-tail` and `aws-ops-dashboard` to `work.el`

These were removed from `.spacemacs` entirely. Add to `work.el`:

```elisp
(require 'cloudwatch-tail)
(bind-key "C-c L" #'cwt-launch)

(require 'aws-ops-dashboard)
(bind-key "C-c D" #'aod-status)
```

The `.el` files themselves stay in `~/.local/emacs/` (already moved there).

### 3. Pull updated `.spacemacs` on the work machine

After steps 1 and 2 are done on the work machine:

```bash
cd ~/dot-spacemacs
git pull          # or: git merge home, or: git rebase home onto master
```

Then restart Emacs. If any packages need syncing: `M-m f e R`.

### 4. Add work-specific registers to `work.el`

All registers except the 5 cross-machine ones were removed from `.spacemacs`.
The cross-machine set (same everywhere) is: `?i` `.spacemacs`, `?b`
`~/.bash_profile`, `?B` `~/.bashrc`, `?e` `~/`, `?o` `dot-org.el`.

Add the rest to `work.el`:

```elisp
(set-register ?t '(file . "~/Box/projects/todo.txt"))   ; adjust path
(set-register ?h '(file . "~/Box/projects/computational-science-general-home-page.org"))
(set-register ?S '(file . "~/Box/projects/standup.org"))
(set-register ?r '(file . "~/src/drupal_scripts/release.sh"))
(set-register ?O '(file . "~/.emacs.d/lisp/dot-org-jira.el"))
```

## Variables already handled correctly

These were fixed in `.spacemacs` and are cross-machine — no action needed:

| Variable | Value | Why cross-machine |
|----------|-------|-------------------|
| `org-clock-persist-file` | `~/.emacs.d/.cache/org-clock-save.el` | Spacemacs cache dir, same everywhere |
| `org-id-locations-file` | `~/.emacs.d/.cache/org-id-locations` | Same |
| `org-clock-sound` | *(removed)* | Was work-specific path, not needed |

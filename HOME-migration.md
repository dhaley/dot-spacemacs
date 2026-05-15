# HOME-migration: Spacemacs + Emacs 30 (emacs-mac build) Setup Guide

## Overview

This documents all edge cases encountered migrating Spacemacs to a custom
emacs-mac 30.2.50 build (jdtsmith/emacs-mac). Use this when setting up
the home machine to avoid repeating these issues.

## Prerequisites

1. Custom emacs-mac build installed (uses GnuTLS, not macOS native TLS)
2. NLR certs at `~/.nrel-certs/ssl/cacert.pem` (from TADA/nrel-certs repo)
3. Spacemacs develop branch at `~/.emacs.d/`

## Critical: early-init.el

The custom emacs-mac build uses GnuTLS directly (not macOS Security framework),
so it can't see certs from Keychain Access. This MUST be in `~/.emacs.d/early-init.el`
BEFORE the `(setq package-enable-at-startup nil)` line:

```elisp
;; NLR CA bundle for GnuTLS — must be set before any TLS connections
(require 'gnutls)
(setq gnutls-trustfiles '("/Users/<username>/.nrel-certs/ssl/cacert.pem"))

;; Fix seq-empty-p compatibility with Emacs 30 package autoloads
(require 'seq)

;; Ensure MELPA is available for package installs
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("gnu"   . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
```

Without this:
- MELPA downloads silently fail (TLS cert verification fails through NLR proxy)
- Package autoloads generation crashes with `cl-no-applicable-method seq-empty-p`
- All packages show "unavailable" on every restart

## .spacemacs Settings

### MELPA Timeout

```elisp
dotspacemacs-elpa-timeout 30  ;; NOT 5 — MELPA archive is 2.5MB, times out through proxy
```

### Package Install Mode

```elisp
dotspacemacs-install-packages 'used-but-keep-unused  ;; prevents orphan deletion loops
```

### Excluded Packages (broken/incompatible with Emacs 30)

```elisp
dotspacemacs-excluded-packages '(org-bullets dap-mode modus-themes info+ undo-fu-session geben)
```

- `info+` — uses deprecated `defadvice`, spams warnings
- `undo-fu-session` — uses deprecated `incf`, replaced by higher `undo-limit`
- `geben` — PHP debugger, last updated 2022, deprecated API warnings
- `ob-php` — removed from MELPA entirely

### Org Babel Languages

Remove `php` from `org-babel-load-languages` in custom-set-variables:
```elisp
'(org-babel-load-languages
  '((python . t) (js . t) (ruby . t) (shell . t) (sql . t) (emacs-lisp . t)))
```

## elpa/develop/ Directory

Spacemacs develop branch stores packages in `~/.emacs.d/elpa/develop/` regardless
of `dotspacemacs-elpa-subdirectory` setting. If packages end up in `~/.emacs.d/elpa/`
(root), they must be copied to `develop/`:

```bash
cd ~/.emacs.d/elpa
for dir in */; do
  [ "$dir" != "develop/" ] && [ "$dir" != "archives/" ] && [ -d "$dir" ] && \
    [ ! -d "develop/$(basename $dir)" ] && cp -r "$dir" "develop/"
done
```

## Packages Not on MELPA (loaded from ~/.emacs.d/lisp/)

These packages are downloaded manually and loaded via `use-package :load-path`:

- `crosshairs.el` — from EmacsWiki (horizontal + vertical cursor tracking)
- `col-highlight.el` — dependency of crosshairs
- `vline.el` — dependency of crosshairs
- `org-sticky-header.el` — shows current heading in header line

Download:
```bash
mkdir -p ~/.emacs.d/lisp
cd ~/.emacs.d/lisp
curl -sO https://www.emacswiki.org/emacs/download/crosshairs.el
curl -sO https://www.emacswiki.org/emacs/download/col-highlight.el
curl -sO https://www.emacswiki.org/emacs/download/vline.el
# org-sticky-header: copy from elpa after first install, or download from GitHub
```

Do NOT put these in `dotspacemacs-additional-packages` — Spacemacs will
delete/reinstall them in a loop due to dependency conflicts.

## Org Version Mismatch

Emacs 30 ships org 9.7.11; Spacemacs installs org 9.8.4 from MELPA.
DO NOT `(require 'org-agenda)` or `(require 'org)` directly in work.el —
it loads the built-in version before Spacemacs loads the MELPA version.

Use `(with-eval-after-load 'org-agenda ...)` instead. The jira agenda
commands will register on first `C-c a` press.

## orgit Package

The `orgit` package from GNU ELPA (2.1.2) must be in `elpa/develop/`.
If missing, copy from `elpa/`:
```bash
cp -r ~/.emacs.d/elpa/orgit-2.1.2 ~/.emacs.d/elpa/develop/
```

## Org Mode from Source

Org-mode is loaded from `~/src/org-mode` (not ELPA/MELPA) to avoid version mismatch issues:

```bash
cd ~/src
git clone https://git.savannah.gnu.org/git/emacs/org-mode.git
cd org-mode
git checkout release_9.8.4
make compile
```

In `.spacemacs`:
- `org` is in `dotspacemacs-excluded-packages` (prevents ELPA install)
- `load-path` is set in `user-init` to `~/src/org-mode/lisp`

To update org: `cd ~/src/org-mode && git pull && make compile`

## Local Lisp Directory

Custom packages live in `~/dot-spacemacs/lisp/` (tracked in git). No symlink needed — `load-path` in `.spacemacs` points directly to `~/dot-spacemacs/lisp`.

After pulling the repo at home:
```bash
cd ~/dot-spacemacs && git pull
```

All local lisp packages (crosshairs, col-highlight, vline, org-sticky-header, orgit, dot-org) are included in the repo.

## Org Files Location

All org files live in `~/Documents/org/`:
- `todo.txt` — main task file
- `from-mobile.org` — mobile capture
- `diary.org` — journal entries

Paths are set in `.spacemacs` custom-set-variables. No overrides in work.el.

## Backup

`backup-each-save` automatically backs up to `~/.backups/` mirroring full paths.
Works for any file location without configuration.

## Undo

Using built-in Emacs undo with higher limit (no undo-fu-session):
```elisp
(setq undo-limit 800000)
```

## Post-Setup Checklist

1. [ ] Clone nrel-certs: `git clone git@github.nrel.gov:TADA/nrel-certs.git ~/.nrel-certs && ~/.nrel-certs/setup`
2. [ ] Pull dot-spacemacs: `cd ~/dot-spacemacs && git pull` (includes lisp/, .spacemacs, dot-org.el, HOME-migration.md)
3. [ ] Copy `early-init.el` additions (gnutls, seq, package-archives) — see early-init section above
4. [ ] Clone org-mode: `cd ~/src && git clone https://git.savannah.gnu.org/git/emacs/org-mode.git && cd org-mode && git checkout release_9.8.4 && make compile`
5. [ ] First start: let all packages install (takes ~5 min)
6. [ ] If "unavailable" errors: check gnutls-trustfiles is set, increase timeout
7. [ ] If seq-empty-p errors: ensure `(require 'seq)` is in early-init
8. [ ] Copy `~/Documents/org/todo.txt` from backup/sync
9. [ ] Verify `C-c a a` shows agenda, `C-c a j d` shows jira
10. [ ] Ensure `~/.emacs.d/elpa/` only contains `archives/` and `develop/` — no package dirs in root

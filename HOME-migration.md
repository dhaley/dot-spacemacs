# HOME-migration: Spacemacs + Emacs 30 (emacs-mac build) Setup Guide

## Overview

This documents all edge cases encountered migrating Spacemacs to a custom
emacs-mac 30.2.50 build (jdtsmith/emacs-mac). Use this when setting up
the home machine to avoid repeating these issues.

## Prerequisites

1. Custom emacs-mac build installed (uses GnuTLS, not macOS native TLS)
2. Certs at `~/.certs/ssl/cacert.pem` (from internal certs repo)
3. Spacemacs develop branch at `~/.emacs.d/`

## Shell Environment

Add to `~/.bash_profile` (or `~/.zprofile` for zsh):

```bash
# Spacemacs: load dotfile from git-tracked directory instead of ~/
export SPACEMACSDIR="$HOME/dot-spacemacs"
```

This eliminates the `~/.spacemacs` symlink — Spacemacs loads
`~/dot-spacemacs/.spacemacs` directly via this env var.

## Critical: .spacemacs user-init

The shared `.spacemacs` `user-init` contains machine-independent setup only
(`seq` compat, native-comp warning suppression, package-archives, org source
load-path). GnuTLS cert config is **machine-specific** and belongs in
`~/.local/emacs/work.el`, not in `.spacemacs`.

### What stays in .spacemacs user-init (both machines)

```elisp
;; Fix seq-empty-p compatibility with Emacs 30 package autoloads
(require 'seq)

;; Suppress byte-compile warnings from third-party packages
(setq native-comp-async-report-warnings-errors 'silent)
(setq byte-compile-warnings '(not obsolete))

;; Ensure MELPA is available for package installs
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("gnu"   . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
```

### What goes in ~/.local/emacs/work.el (work machine only)

The work emacs-mac build uses GnuTLS directly (not macOS Security framework)
and can't see certs from Keychain Access. These lines must be in `work.el`
and are loaded during `dotspacemacs/user-init` before any TLS connections:

```elisp
;; CA bundle for GnuTLS — must be set before any TLS connections
(require 'gnutls)
(setq gnutls-trustfiles '("~/.certs/ssl/cacert.pem"))
```

Without this at work:
- MELPA downloads silently fail (TLS cert verification fails through corporate proxy)
- All packages show "unavailable" on every restart

**IMPORTANT:** Never modify `~/.emacs.d/early-init.el` — it is managed by
Spacemacs and will be overwritten on updates.

## Pulling master at Work

After any `git pull` on the work machine, verify `~/.local/emacs/work.el`
still contains the gnutls lines above. Commit `d983637` removed them from
`.spacemacs` (they were never correct there — home has no corporate proxy).
If they are missing from `work.el`, MELPA will silently time out and all
packages will show as unavailable on the next restart.

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

## Packages Not on MELPA (loaded from ~/dot-spacemacs/lisp/)

These packages are tracked in the `dot-spacemacs` git repo under `lisp/`:

- `crosshairs.el` — horizontal + vertical cursor tracking
- `col-highlight.el` — dependency of crosshairs
- `vline.el` — dependency of crosshairs
- `org-sticky-header.el` — shows current heading in header line

Source (if re-downloading needed):
```bash
cd ~/dot-spacemacs/lisp
curl -sLO https://raw.githubusercontent.com/emacsmirror/crosshairs/master/crosshairs.el
curl -sLO https://raw.githubusercontent.com/emacsmirror/col-highlight/master/col-highlight.el
curl -sLO https://raw.githubusercontent.com/emacsmirror/vline/master/vline.el
```

**NOTE:** EmacsWiki download URLs return HTML — always use emacsmirror GitHub raw URLs.

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
- `org` is in `dotspacemacs-frozen-packages` (keeps ELPA copy but prevents updates)
- `load-path` is set in `user-init` to prioritize `~/src/org-mode/lisp`
- Do NOT delete the ELPA org directory — Spacemacs needs it to satisfy dependencies
- Do NOT byte-recompile the ELPA org `.elc` files — they'll compile against wrong version

To update org: `cd ~/src/org-mode && git pull && make compile`

## org-jira from Source

```bash
cd ~/src
git clone <org-jira-repo-url> org-jira
```

Load-path set in `.spacemacs` user-init. Custom commands in `~/dot-spacemacs/dot-org-jira.el`.

## Local Lisp Directory

Custom packages live in `~/dot-spacemacs/lisp/` (tracked in git). Load-path in
`.spacemacs` points directly to `~/dot-spacemacs/lisp`.

**NEVER add files to `~/.emacs.d/`** — that directory is entirely managed by
Spacemacs (the syl20bnr/spacemacs repo) and may be overwritten.

After pulling the repo at home:
```bash
cd ~/dot-spacemacs && git pull
```

All local lisp packages (crosshairs, col-highlight, vline, org-sticky-header) are included in the repo.

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

## magit-todos

The `magit-todos` scanner (ripgrep) may error in repos where all files are
gitignored. This is silenced with `ignore-errors` advice in `.spacemacs`
user-config — no action needed.

## Post-Setup Checklist

1. [ ] Clone certs: `git clone <internal-certs-repo> ~/.certs && ~/.certs/setup`
2. [ ] Add `export SPACEMACSDIR="$HOME/dot-spacemacs"` to `~/.bash_profile`
3. [ ] Pull dot-spacemacs: `cd ~/dot-spacemacs && git pull` (includes lisp/, .spacemacs, dot-org.el, dot-org-jira.el, HOME-migration.md)
4. [ ] Remove `~/.spacemacs` symlink if it exists (SPACEMACSDIR replaces it)
5. [ ] Clone org-mode: `cd ~/src && git clone https://git.savannah.gnu.org/git/emacs/org-mode.git && cd org-mode && git checkout release_9.8.4 && make compile`
6. [ ] Clone org-jira: `cd ~/src && git clone <org-jira-repo> org-jira`
7. [ ] First start: let all packages install (takes ~5 min)
8. [ ] If "unavailable" errors at work: check `~/.local/emacs/work.el` has gnutls-trustfiles set (see "Pulling master at Work" section)
9. [ ] If seq-empty-p errors: ensure `(require 'seq)` is in user-init
10. [ ] Copy `~/Documents/org/todo.txt` from backup/sync
11. [ ] Verify `C-c a a` shows agenda, `C-c a j d` shows jira with deadlines
12. [ ] Ensure `~/.emacs.d/elpa/` only contains `archives/` and `develop/` — no package dirs in root
13. [ ] Do NOT run `byte-recompile-directory` on `elpa/develop/` — it recompiles ELPA org against wrong version

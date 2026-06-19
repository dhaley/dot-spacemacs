# Home Migration

Dependencies needed on the home machine after pulling latest changes.

## Homebrew packages

```bash
brew install pandoc
```

## Emacs packages (auto-installed on restart)

These install automatically via `dotspacemacs-additional-packages`:
- `edit-indirect`
- `markdown-preview-mode`

These install via `package-vc-selected-packages` (custom-set-variables):
- `pg` (from github.com/emarsden/pg-el)
- `pgmacs` (from github.com/emarsden/pgmacs)

## Vendored lisp (no install needed)

These are tracked in `lisp/` and loaded automatically:
- `pandoc-mode.el` + `pandoc-mode-utils.el`
- `modus-themes` (v5.2.0)
- `ef-themes` (v2.1.0)
- `crosshairs.el`, `col-highlight.el`, `vline.el`
- `org-sticky-header.el`, `orgit.el`

## Removed packages

- `catppuccin-theme` - removed from additional-packages
- `pandoc-mode` - added to excluded-packages (using vendored local copy instead)

## After pulling

```bash
cd ~/dot-spacemacs
git pull
```

Then restart Emacs. Spacemacs will install any new packages on startup.

If you get "Package not found" errors for pg/pgmacs, run:
```
M-: (package-vc-install "https://github.com/emarsden/pg-el" nil nil 'pg)
M-: (package-vc-install "https://github.com/emarsden/pgmacs" nil nil 'pgmacs)
```

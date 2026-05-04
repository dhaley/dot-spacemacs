# CLAUDE.md

This is the user's personal Spacemacs configuration.

## Spacemacs — holy-mode

This setup uses **holy-mode** (standard Emacs keybindings), NOT evil-mode or vim keybindings.

- Leader key is `M-m` (not `SPC`)
- Use `M-m f e R` to reload `.spacemacs` (not `SPC f e R`)
- All keybinding suggestions should use `C-x`, `M-x`, `C-c` style — no vim motions

## Config layout

- `.spacemacs` — main Spacemacs config (cross-machine)
- `dot-org.el` — Org-mode configuration
- `home.el.template` — template for machine-specific overrides
- `~/.local/emacs/home.el` — machine-specific and sensitive config (NOT committed to any public repo)
- `~/src/dot-emacs/` — public Emacs config toolbox (also called "doc-spacemacs")

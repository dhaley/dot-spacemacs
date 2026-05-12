# CLAUDE.md

This is the user's personal Spacemacs configuration.

## Spacemacs — holy-mode

This setup uses **holy-mode** (standard Emacs keybindings), NOT evil-mode or vim keybindings.

- Leader key is `M-m` (not `SPC`)
- Use `M-m f e R` to reload `.spacemacs` (not `SPC f e R`)
- All keybinding suggestions should use `C-x`, `M-x`, `C-c` style — no vim motions

## Config layout

- `.spacemacs` — main Spacemacs config (shared between home and work machines)
- `dot-org.el` — Org-mode configuration
- `~/.local/emacs/` — machine-specific config (NOT committed to any public repo)
  - At work: `work.el` (Jira, AWS, MCP tools, Deepagents)
  - At home: `home.el` (Claude personal account, claude-code-ide)

## Branch strategy

- `master` — shared config that works on both home and work machines
- Machine-specific config lives in `~/.local/emacs/` (not in this repo)

## Switching home from `home` branch to `master`

The `home` branch has Claude-specific config baked into `.spacemacs`. On `master`, that config must move to `~/.local/emacs/home.el`.

### Steps:

1. Append the content below to `~/.local/emacs/home.el` (file already exists)
2. `cd ~/dot-spacemacs && git checkout master`
3. Restart Emacs — verify it loads without errors

### Append to ~/.local/emacs/home.el:

```elisp
;;; home.el — Home-specific Emacs config (Claude, personal accounts)

;; ── Load paths for claude-code-ide ────────────────────────────────────────
(add-to-list 'load-path "~/src/dot-emacs/lisp/claude-code-ide")
(add-to-list 'load-path "~/src/dot-emacs/lisp")

;; ── gptel: use personal Claude account via OAuth ──────────────────────────
(with-eval-after-load 'gptel
  (require 'gptel-anthropic-oauth)
  (let ((claude (gptel-make-anthropic-oauth "Claude" :stream t)))
    (setq gptel-backend claude
          gptel-model 'claude-sonnet-4-6)))

;; ── claude-code-ide: Claude Code CLI ↔ Emacs via WebSocket MCP ────────────
(use-package claude-code-ide
  :demand t
  :bind ("C-x c c" . claude-code-ide-menu)
  :custom
  (claude-code-ide-cli-extra-flags "--dangerously-skip-permissions")
  :config
  (claude-code-ide-emacs-tools-setup))

;; ── free-keys: show unbound keys in current context ───────────────────────
(use-package free-keys
  :ensure t
  :commands free-keys)
```

### What changed between `home` and `master`:

- `modus-themes` is now excluded from ELPA (uses Emacs 30 built-in) — same behavior
- `gptel-use-curl` uses multi-path lookup (works on both Intel and Apple Silicon)
- `browse-url` uses macOS default browser (not w3m)
- `themes-megapack` layer removed (not needed with built-in modus-themes)
- Claude-specific config (gptel-anthropic-oauth, claude-code-ide) moved to `~/.local/emacs/home.el`

### Verification after switch:

- `C-c g` should open gptel (Claude backend from home.el)
- `C-x c c` should open claude-code-ide menu
- `M-m f e R` should reload without errors
- Modus theme should load correctly (built-in version)

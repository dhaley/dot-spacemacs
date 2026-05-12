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

## What goes where

### In `.spacemacs` (shared):
- Package declarations (use-package, additional-packages)
- Keybindings (C-c g, C-', C-", etc.)
- UI/UX preferences (themes, org-mode, helpful, etc.)
- claude-code-ide use-package (CLI path resolution works everywhere)

### In `~/.local/emacs/` (machine-specific):
- **gptel backends/providers** — home uses Anthropic OAuth, work uses AWS Bedrock
- **gptel model selection** — different models available per account
- **MCP server configs** — different tools at home vs work
- **Credentials/tokens** — API keys, AWS profiles
- Any config that references account-specific resources (inference profiles, endpoints)

## Switching home from `home` branch to `master`

The `home` branch has Claude-specific config baked into `.spacemacs`. On `master`, that config must move to `~/.local/emacs/home.el`.

### Steps:

1. Append the content below to `~/.local/emacs/home.el` (file already exists)
2. `cd ~/dot-spacemacs && git checkout master`
3. Restart Emacs — verify it loads without errors

### Append to ~/.local/emacs/home.el:

```elisp
;;; home.el — Home-specific Emacs config (Claude, personal accounts)

;; ── gptel: configure Claude subscription backend ──────────────────────────
;; The shared .spacemacs defines keybindings (C-c g, C-c G, C-c M-g) and
;; the my/gptel-with-backend selector. Backends themselves are defined here
;; because they differ between home (Anthropic OAuth) and work (AWS Bedrock).
(with-eval-after-load 'gptel
  (require 'gptel-anthropic-oauth)
  (setq gptel-model 'claude-sonnet-4-6
        gptel-backend
        (gptel-make-anthropic-oauth "Claude" :stream t))

  ;; Optional: add a second backend for variety
  ;; (gptel-make-anthropic-oauth "Claude-Opus" :stream t)
  )

;; ── claude-code-ide: uses personal Claude subscription via CLI ────────────
;; The CLI authenticates via `claude login` (not Bedrock).
;; No env vars needed — the CLI handles auth itself.
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

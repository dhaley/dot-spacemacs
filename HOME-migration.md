# HOME Migration — 2026-05-19

Changes since Sunday 2026-05-18 that need to be applied at home.

## Homebrew Dependencies

```bash
brew install terminal-notifier   # Required by agent-shell-macext for native macOS notifications
brew install pngpaste            # Required by agent-shell for clipboard image support
```

## npm Global Dependencies

```bash
npm install -g @agentclientprotocol/claude-agent-acp   # ACP adapter for Claude Code in agent-shell
```

## Claude Code Plugin

```bash
claude plugin marketplace add xenodium/emacs-skills
claude plugin install emacs-skills@xenodium-emacs-skills
```

## Emacs Packages Added (in ~/dot-spacemacs/lisp/)

These are tracked as normal files — no action needed beyond `git pull`:

- `lisp/agent-shell-macext/` — macOS notifications, Finder drag-drop, smart file copy for agent-shell
- `lisp/ob-agent-shell/` — org-babel backend for agent-shell (`#+begin_src agent-shell` blocks)
- `lisp/agent-shell-org-transcript/` — saves agent-shell transcripts as .org files in org-roam-directory

## .spacemacs Changes

- Added `markdown-command` set to `/opt/homebrew/bin/pandoc`
- Added `agent-shell-macext` use-package config
- Added `ob-agent-shell` use-package config

## Emacs MCP Servers (elisp-dev-mcp + org-mcp)

These MCP servers let Claude Code introspect Emacs Lisp and read/write Org files
via your running Emacs daemon.

### Prerequisites

1. Emacs daemon must be running (`server-start` is called in `.spacemacs`)
2. `emacsclient` must be on PATH
3. Packages already configured in `.spacemacs`: `mcp-server-lib`, `elisp-dev-mcp`, `org-mcp`
4. The stdio script is installed at `~/.emacs.d/emacs-mcp-stdio.sh` — if missing, run `M-x mcp-server-lib-install` in Emacs

### Register with Claude Code

```bash
claude mcp add -s user -t stdio elisp-dev-mcp -e EDITOR=emacsclient -- \
  ~/.emacs.d/emacs-mcp-stdio.sh \
  --init-function=elisp-dev-mcp-enable \
  --stop-function=elisp-dev-mcp-disable \
  --server-id=elisp-dev-mcp

claude mcp add -s user -t stdio org-mcp -e EDITOR=emacsclient -- \
  ~/.emacs.d/emacs-mcp-stdio.sh \
  --init-function=org-mcp-enable \
  --stop-function=org-mcp-disable \
  --server-id=org-mcp
```

### Verify

```bash
claude mcp list   # Both should show ✓ Connected
```

### Troubleshooting

- If `✗ Failed to connect`: ensure Emacs daemon is running and `emacsclient -e "(+ 1 1)"` returns `2`
- The `-e EDITOR=emacsclient` flag is required because Claude Code doesn't inherit shell env vars
- Debug: `EMACS_MCP_DEBUG_LOG=/tmp/mcp-debug.log` can be added as another `-e` flag

### Available Tools

**elisp-dev-mcp:** `elisp-describe-function`, `elisp-get-function-definition`, `elisp-describe-variable`, `elisp-info-lookup-symbol`, `elisp-read-source-file`

**org-mcp:** `org-read-file`, `org-read-outline`, `org-read-headline`, `org-read-by-id`, `org-add-todo`, `org-update-todo-state`, `org-rename-headline`, `org-edit-body`, `org-get-todo-config`, `org-get-tag-config`, `org-get-allowed-files`

## Notes

- `~/.local/emacs/home.el` may need the Claude Code agent-shell config added (the `claude-code` identifier in `agent-shell-agent-configs`) — check work.el for reference
- Claude Code config lives at `~/.claude.json` (MCP servers) and `~/.claude/settings.json` (Bedrock env vars) — these are machine-specific and not synced via dot-spacemacs

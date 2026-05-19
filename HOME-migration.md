# HOME Migration — 2026-05-19

Changes since Sunday 2026-05-18 that need to be applied at home.

## Homebrew Dependencies

```bash
brew install terminal-notifier   # Required by agent-shell-macext for native macOS notifications
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

## .spacemacs Changes

- Added `markdown-command` set to `/opt/homebrew/bin/pandoc`
- Added `agent-shell-macext` use-package config
- Added `ob-agent-shell` use-package config

## Notes

- `~/.local/emacs/home.el` may need the Claude Code agent-shell config added (the `claude-code` identifier in `agent-shell-agent-configs`) — check work.el for reference
- Claude Code config lives at `~/.claude.json` (MCP servers) and `~/.claude/settings.json` (Bedrock env vars) — these are machine-specific and not synced via dot-spacemacs

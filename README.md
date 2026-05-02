# dot-spacemacs

Personal Spacemacs configuration for macOS (Holy mode / Emacs keybindings). Work-specific config (Jira, AWS, MCP servers, internal URLs) lives in `~/.local/emacs/` and is not included here.

## Quick Start

```bash
# 1. Install Emacs
brew tap railwaycat/emacsmacport
brew install emacs-mac@29

# 2. Clone Spacemacs (develop branch)
git clone -b develop https://github.com/syl20bnr/spacemacs ~/.emacs.d

# 3. Clone this config
git clone git@github.com:dhaley/dot-spacemacs.git ~/dot-spacemacs
ln -s ~/dot-spacemacs/.spacemacs ~/.spacemacs

# 4. Symlink elisp files into Spacemacs load-path
mkdir -p ~/.emacs.d/lisp
ln -s ~/dot-spacemacs/dot-org.el ~/.emacs.d/lisp/dot-org.el
ln -s ~/dot-spacemacs/org-smart-capture.el ~/.emacs.d/lisp/org-smart-capture.el
ln -s ~/dot-spacemacs/dot-org-jira.el ~/.emacs.d/lisp/dot-org-jira.el
ln -s ~/dot-spacemacs/cloudwatch-tail.el ~/.emacs.d/lisp/cloudwatch-tail.el

# 5. Set up local config
mkdir -p ~/.local/emacs
cp ~/dot-spacemacs/home.el.template ~/.local/emacs/home.el
# Edit ~/.local/emacs/home.el — set your org file path and email

# 6. Create org files
mkdir -p ~/Documents/org
echo "* Inbox                                                :REFILE:" > ~/Documents/org/todo.txt
touch ~/Documents/org/diary.org

# 7. Install dependencies
brew install aspell coreutils curl git node ripgrep tree-sitter cmake python@3.12 trash

# 8. Launch Emacs — Spacemacs will install all packages (takes a few minutes)
emacs
# After packages install, restart Emacs
```

## Prerequisites

### macOS

Tested on macOS Sequoia (15.x), Apple Silicon (M-series).

### Emacs

YAMAMOTO Mitsuharu's Mac port — native macOS integration, pixel-smooth scrolling, better performance.

```bash
brew tap railwaycat/emacsmacport
brew install emacs-mac@29
```

Current version: GNU Emacs 29.4 (Mac port)

To add to Applications:

```bash
osascript -e 'tell application "Finder" to make alias file to POSIX file "/opt/homebrew/opt/emacs-mac@29/Emacs.app" at POSIX file "/Applications"'
```

### Spacemacs

Using the `develop` branch:

```bash
git clone -b develop https://github.com/syl20bnr/spacemacs ~/.emacs.d
```

To update Spacemacs:

```bash
cd ~/.emacs.d && git pull
```

Then restart Emacs — it will sync packages automatically.

### Homebrew packages

```bash
# Required
brew install aspell            # spell checking
brew install coreutils         # gls for dired (insert-directory-program)
brew install curl              # newer curl (>= 8.9 for gptel-bedrock sigv4)
brew install git
brew install node              # copilot language server
brew install ripgrep           # fast search (C-c s p)
brew install tree-sitter       # syntax highlighting
brew install cmake             # vterm native compilation
brew install python@3.12       # org-jira, various tools
brew install trash             # macOS trash for file deletion

# Optional
brew install git-lfs           # large file support
brew install git-filter-repo   # history rewriting
brew install screen            # org-babel screen sessions
brew install nvm               # Node version management
brew install --cask font-source-code-pro  # default Spacemacs font
```

### Shell configuration

Add to `~/.bash_profile` or `~/.zshrc`:

```bash
# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# uv-installed tools (deepagents-cli, etc.)
export PATH="$HOME/.local/bin:$PATH"

# NVM (optional, for Node version management)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

## Configuration

### Editing style

This config uses **Holy mode** (Emacs keybindings), not Evil/Vim:

```elisp
dotspacemacs-editing-style 'emacs
```

The leader key is `M-m` (or use `C-c` prefix for custom bindings).

### Layers

```
rust nginx go sql php docker ansible ruby csv yaml javascript html
compleseus auto-completion emacs-lisp git latex markdown org
spell-checking syntax-checking osx themes-megapack lsp terraform
python github-copilot
```

### Additional packages

```
persistent-scratch geben writeroom-mode ob-php gptel mcp
shell-maker acp agent-shell eat request dash org-super-agenda
```

## Local Config (`~/.local/emacs/`)

The `.spacemacs` file works standalone with generic defaults. Machine-specific config goes in `~/.local/emacs/` — all `.el` files there are loaded automatically during `dotspacemacs/user-init` (before packages load).

### How it works

```
~/.spacemacs                    # Public config (this repo)
  └─ dotspacemacs/user-init
       └─ loads ~/.local/emacs/*.el   # Machine-specific overrides
```

### What goes in local config

| Setting | Variable | Example |
|---------|----------|---------|
| Org file location | `my/org-base-dir` | `"~/Documents/org"` or `"~/Dropbox/org"` |
| Email | `user-mail-address` | `"you@example.com"` |
| Org capture templates | `org-capture-templates` | Override in `emacs-startup-hook` |
| Agenda commands | `org-agenda-custom-commands` | Append via `add-to-list` |
| LLM backend | `gptel-backend` / `gptel-model` | OpenAI, Bedrock, Ollama, etc. |
| MCP servers | `mcp-hub-servers` | Set before mcp-hub loads |
| SSL certificates | `SSL_CERT_FILE` etc. | Corporate proxy CA bundles |
| Keybindings | `global-set-key` | Use `emacs-startup-hook` for timing |

### Templates

- **`home.el.template`** — Minimal starter for a home machine (org paths, email)
- For work config, create a private repo and clone to `~/.local/emacs/`

### Timing

Local config loads in `dotspacemacs/user-init` which runs **before** package/layer configuration. This means:

- `setq` on variables works — packages will see your values
- `with-eval-after-load` works for package-specific config
- `emacs-startup-hook` runs **after** everything, good for overriding `custom-set-variables`

## First Launch

1. Start Emacs — Spacemacs will detect missing packages and install them
2. Wait for installation to complete (watch the mode-line progress)
3. Restart Emacs when prompted
4. Run `M-m f e R` (or `M-x dotspacemacs/sync-configuration-layers`) to ensure everything is synced
5. If any packages fail, check `*Messages*` buffer (`M-m b m`)

## Package Updates

```
M-m f e U    # Update all packages
```

Or click `[Update Packages]` on the Spacemacs home buffer.

## Custom Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| `C-c g` | `gptel` | Open LLM chat |
| `C-c G` | `gptel-send` | Send region/buffer to LLM |
| `C-c M-g` | `gptel-menu` | LLM settings menu |
| `C-c c` | `org-capture` | Capture task/note |
| `C-c a` | `org-agenda` | Open agenda |
| `H-M-S-RET` | `org-smart-capture` | Context-aware capture |

Additional keybindings may be defined in `~/.local/emacs/` for machine-specific tools.

## org-jira (optional)

If you use Jira, this config supports a local fork of org-jira at `~/src/org-jira`:

```bash
git clone git@github.com:dhaley/org-jira.git ~/src/org-jira
```

The fork includes patches for Jira Server compatibility. See `~/src/org-jira/LOCAL-PATCHES.md`.

Jira configuration (URL, token, team members) goes in `~/.local/emacs/work.el`, not in this repo.

## Troubleshooting

### Emacs can't find gls

```bash
brew install coreutils
```

### gptel curl version error

gptel-bedrock needs curl >= 8.9. The config uses Homebrew's curl at `/opt/homebrew/opt/curl/bin/curl`.

```bash
brew install curl
```

### Stale .elc files

Don't byte-compile dotfiles. Delete stale compiled files:

```bash
find ~/dot-spacemacs -name "*.elc" -delete
```

### Packages fail on first launch

Restart Emacs. If still failing, run `M-m f e R` to re-sync.

### Local config not loading

Check that `~/.local/emacs/` exists and contains `.el` files (not `.el~` or other extensions).

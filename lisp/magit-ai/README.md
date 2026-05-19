# magit-ai

I've been working on [git-ai](https://github.com/jwiegley/git-ai) for tracking
which parts of my code come from AI tools -- Claude Code, Cursor, Copilot, and
the rest.  It stores per-line authorship metadata in git notes, which keeps this
information in the repo without cluttering up your actual commits.

The problem was, I do all my git work in Magit.  And while `git-ai blame` and
`git-ai stats` work fine from the terminal, I wanted to see this data where I
actually live -- in the status buffer, in blame overlays, in diffs.  So I built
magit-ai.

## What you get

An AI stats section in the Magit status buffer:

```
AI Authorship
  42% AI (Claude: 30, Cursor: 12)
  58% Human
```

Per-line AI blame overlays, similar to `magit-blame` but showing which tool
wrote each line:

```
abc1234 [Claude]  (defun my-function ()
def5678 [Human]     "A function I wrote."
ghi9012 [Cursor]    (let ((x 1))
```

Margin annotations in diff buffers:

```
  Claude   | +  (defun ai-generated ()
  Human    | +    "But I wrote this line."
  Cursor   | +    (do-something))
```

And AI percentage annotations in the commit log:

```
  42%  abc1234 Add new feature
   0%  def5678 Fix typo
  15%  ghi9012 Refactor module
```

Each tool gets its own face -- Claude is purple, Cursor is blue, Copilot is
green, Gemini is amber.

## Requirements

- Emacs 28.1+
- [Magit](https://magit.vc/) 4.0+
- [git-ai](https://github.com/jwiegley/git-ai)

## Installation

With `use-package` and `straight.el`:

```elisp
(use-package magit-ai
  :straight (:host github :repo "jwiegley/magit-ai")
  :after magit)
```

Or add the directory to your `load-path` and `(require 'magit-ai)`.  The
package hooks into Magit's blame, diff, and log modes automatically when the
corresponding `magit-ai-show-in-*` variables are non-nil (they are by default).

## Usage

Press `` ` `` in any Magit buffer to open the transient menu.  From there:

| Key | What it does |
|-----|-------------|
| `b` | AI blame for a file |
| `B` | AI blame for the current buffer |
| `s` | Stats for HEAD |
| `S` | Stats for the commit at point |
| `d` | Diff with AI annotations |
| `p` | View the prompt that generated code at point |
| `v` | git-ai version |

To change the prefix key:

```elisp
(setq magit-ai-mode-map-prefix "I")
```

## Customization

The display toggles all default to `t`:

```elisp
(setq magit-ai-show-in-status t)
(setq magit-ai-show-in-blame t)
(setq magit-ai-show-in-diff t)
```

Stats are cached for 30 seconds by default:

```elisp
(setq magit-ai-stats-cache-ttl 60)
```

You can tweak the per-tool colors:

```elisp
(set-face-attribute 'magit-ai-author-claude nil :foreground "#8B5CF6")
(set-face-attribute 'magit-ai-author-cursor nil :foreground "#3B82F6")
(set-face-attribute 'magit-ai-author-copilot nil :foreground "#10B981")
(set-face-attribute 'magit-ai-author-gemini nil :foreground "#F59E0B")
```

## How it works

The package has a few modules.  `magit-ai-process.el` is the foundation -- it
handles binary discovery, running `git-ai` subprocesses, JSON parsing, and
caching (following Magit's own patterns for process management).  `magit-ai.el`
provides the transient menu and user-facing commands.  The display modules --
`magit-ai-sections.el`, `magit-ai-blame.el`, `magit-ai-diff.el`, and
`magit-ai-log.el` -- each hook into their respective Magit modes.

Everything degrades gracefully: if `git-ai` isn't installed or the repo doesn't
have AI notes, you just don't see anything.

## Development

```bash
make compile       # byte-compile with warnings as errors
make test          # run ERT tests
make lint          # full lint (compile + checkdoc)
make format        # fix indentation
make format-check  # verify indentation
make coverage      # function-level coverage report
make benchmark     # performance benchmarks
```

With Nix:

```bash
nix develop        # enter dev shell with all dependencies
nix build          # byte-compile the package
nix flake check    # run all checks (compile, test, format, checkdoc)
```

## License

BSD 3-clause.  See [LICENSE.md](LICENSE.md).

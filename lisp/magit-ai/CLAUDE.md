# CLAUDE.md - magit-ai Project Guide

## Project Overview

**magit-ai** is an Emacs Lisp package that integrates AI authorship tracking into Magit. It bridges the external **git-ai** Rust CLI tool (which stores AI authorship metadata via git notes) with Emacs/Magit's user interface, displaying which lines of code were written by AI tools versus humans.

## Quick Start

```bash
# Run tests
make test

# Byte-compile
make compile

# Clean compiled files
make clean
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
├───────────────┬───────────────┬───────────────┬────────────────┤
│  magit-ai.el  │ magit-ai-    │ magit-ai-     │ magit-ai-      │
│  (Transient   │ sections.el  │ blame.el      │ diff.el        │
│   Commands)   │ (Status)     │ (Overlays)    │ (Annotations)  │
├───────────────┴───────────────┴───────────────┴────────────────┤
│                    magit-ai-process.el                         │
│            (Core process mgmt, faces, caching)                 │
├────────────────────────────────────────────────────────────────┤
│                        git-ai CLI                              │
│                    (External Rust tool)                        │
└────────────────────────────────────────────────────────────────┘
```

## Module Guide

| File | Purpose |
|------|---------|
| `magit-ai-process.el` | Foundation: binary discovery, process execution, JSON parsing, faces, TTL caching |
| `magit-ai.el` | Main entry: transient menu (bound to `A`), user commands, keybinding setup |
| `magit-ai-sections.el` | Status buffer section inserters (`magit-insert-ai-stats`) |
| `magit-ai-blame.el` | EIEIO-based blame chunks, async blame process, overlay management |
| `magit-ai-diff.el` | Diff annotation parsing, margin/fringe overlay display |
| `magit-ai-log.el` | Commit log AI percentage annotations, commit highlighting |

## Key Patterns

### Process Execution (mirrors Magit patterns)

```elisp
;; Synchronous - for output capture
(magit-ai-string &rest args)    ; Returns first line
(magit-ai-output &rest args)    ; Returns full output
(magit-ai-lines &rest args)     ; Returns list of lines
(magit-ai-json &rest args)      ; Returns parsed JSON alist

;; Asynchronous - with process sentinel
(magit-ai-run-async &rest args) ; Returns process object
```

### EIEIO Classes

```elisp
;; Blame chunk with line ranges and tool info
(defclass magit-ai-blame-chunk ()
  ((line-start :initarg :line-start :type integer)
   (line-end   :initarg :line-end   :type integer)
   (tool       :initarg :tool       :initform nil)
   (author     :initarg :author     :initform nil)
   (prompt-id  :initarg :prompt-id  :initform nil)))

;; Section class for status buffer
(defclass magit-ai-stats-section (magit-section)
  ((stats :initform nil :initarg :stats)))
```

### Minor Mode Pattern

Each display feature follows this structure:
1. `define-minor-mode` with `:lighter` for mode line
2. `--enable` function: check availability, fetch data, create overlays
3. `--disable` function: remove overlays, clear state
4. Hook integration for automatic activation

### Namespacing Convention

- Public API: `magit-ai-` prefix
- Internal functions: `magit-ai--` double-dash prefix
- Buffer-local vars: `magit-ai-{module}-` prefix

## Supported AI Tools

| Tool ID | Face | Display Name |
|---------|------|--------------|
| `claude-code`, `claude` | `magit-ai-author-claude` | Claude |
| `cursor` | `magit-ai-author-cursor` | Cursor |
| `github-copilot`, `copilot` | `magit-ai-author-copilot` | Copilot |
| `gemini` | `magit-ai-author-gemini` | Gemini |
| `continue-cli` | `magit-ai-author-continue` | Continue |
| Unknown tools | `magit-ai-author` | Capitalized name |

## Key Customization Variables

```elisp
;; Process (magit-ai-process.el)
magit-ai-executable              ; Path to git-ai binary ("git-ai")
magit-ai-global-arguments        ; Args for all invocations (nil)
magit-ai-environment             ; Alist of env vars (nil)

;; Display toggles (magit-ai-process.el)
magit-ai-show-in-status          ; Show in status buffer (t)
magit-ai-show-in-blame           ; Show in blame mode (t)
magit-ai-show-in-diff            ; Show in diff mode (t)

;; Tool faces (magit-ai-process.el)
magit-ai-tool-face-alist         ; Tool name -> face mapping
magit-ai-unknown-tool-face       ; Fallback face ('magit-ai-author)

;; Keybinding (magit-ai.el)
magit-ai-mode-map-prefix         ; Keybinding prefix ("A")

;; Diff annotations (magit-ai-diff.el)
magit-ai-diff-annotation-style   ; margin/fringe/both ('margin)
magit-ai-diff-margin-width       ; Margin width (10)

;; Blame display (magit-ai-blame.el)
magit-ai-blame-style             ; ai-headings/ai-margin ('ai-margin)
magit-ai-blame-styles            ; Alist of style definitions

;; Log display (magit-ai-log.el)
magit-ai-log-show-percentage     ; Show AI % in logs (t)
magit-ai-log-highlight-ai-commits ; Highlight AI commits (t)
magit-ai-log-percentage-threshold ; Min % to highlight (10)

;; Sections (magit-ai-sections.el)
magit-ai-stats-section-visibility ; Initial visibility ('hide)

;; Performance (magit-ai-process.el)
magit-ai-stats-cache-ttl         ; Cache TTL in seconds (30)
```

## Testing

Tests use mock-based approach without requiring git-ai binary:

```elisp
;; Mock macros
(magit-ai-with-mock-executable &body)   ; Mock binary present
(magit-ai-with-mock-unavailable &body)  ; Mock binary absent
(magit-ai-with-mock-output output &body) ; Mock command output
(magit-ai-with-mock-json json &body)    ; Mock JSON response

;; Run specific tests
M-x ert RET magit-ai-test- RET
```

## Autoloaded Commands

From `magit-ai.el`:
- `magit-ai` - Transient menu (bound to prefix key, default `A`)
- `magit-ai-blame-file` - AI blame for a file
- `magit-ai-blame-buffer` - AI blame for current buffer
- `magit-ai-show-stats` - Show AI/human stats
- `magit-ai-show-stats-at-point` - Stats for commit at point
- `magit-ai-show-diff` - AI-annotated diff
- `magit-ai-show-prompt` - View generation prompt
- `magit-ai-working-status` - Uncommitted AI data
- `magit-ai-show-version` - git-ai version

From `magit-ai-blame.el`:
- `magit-ai-blame-mode` - Minor mode for blame overlays
- `magit-ai-blame-toggle` - Toggle blame mode
- `magit-ai-blame-chunk-at-point` - Get chunk at point
- `magit-ai-blame-show-prompt-at-point` - Show prompt for code at point

From `magit-ai-diff.el`:
- `magit-ai-diff-mode` - Minor mode for diff annotations
- `magit-ai-diff-toggle` - Toggle diff mode
- `magit-ai-diff-refresh` - Refresh annotations

From `magit-ai-log.el`:
- `magit-ai-log-mode` - Minor mode for log annotations
- `magit-ai-log-toggle` - Toggle log mode
- `magit-ai-log-show-stats-at-point` - Show stats for commit at point

From `magit-ai-sections.el`:
- `magit-insert-ai-stats` - Section inserter (full)
- `magit-insert-ai-stats-header` - Section inserter (compact)

## Dependencies

- **Emacs 28.1+**
- **Magit 4.0+** (magit-process, magit-diff, magit-blame, magit-log, magit-section)
- **transient** (for menu system)
- **git-ai** (external Rust CLI tool)

## Known Issues / Notes

- **No global `magit-ai-mode`**: The README mentions `(magit-ai-mode 1)` in use-package
  examples, but this mode is not defined. The package auto-enables via hooks on
  `magit-blame-mode-hook`, `magit-diff-mode-hook`, and `magit-log-mode-hook` when
  the corresponding `magit-ai-show-in-*` variables are non-nil.

## Adding a New AI Tool

1. Add face definition in `magit-ai-process.el`:
```elisp
(defface magit-ai-author-newtool
  '((((class color) (background light)) :foreground "#...")
    (((class color) (background dark))  :foreground "#..."))
  "Face for NewTool-authored code."
  :group 'magit-faces)
```

2. Add to `magit-ai-tool-face-alist`:
```elisp
("newtool" . magit-ai-author-newtool)
```

3. Add display name in `magit-ai--format-tool-name`:
```elisp
("newtool" "NewTool")
```

4. Add regex in `magit-ai-blame--extract-tool` if needed.

## Common Tasks

### Adding a new command
1. Define in `magit-ai.el` with `;;;###autoload`
2. Add to transient menu in `transient-define-prefix magit-ai`
3. Use `magit-ai--with-check` macro for availability check

### Adding a new section
1. Create section inserter function in `magit-ai-sections.el`
2. Use `magit-insert-section` macro
3. Add to `magit-status-sections-hook` in user config

### Extending blame parsing
1. Modify `magit-ai-blame--extract-tool` regex patterns
2. Update `magit-ai-blame--parse-output` if format changes
3. Add tests in `test/magit-ai-tests.el`

## Code Style

- All files use `lexical-binding: t`
- Comprehensive docstrings for all public functions
- Follow Magit's established patterns for process management
- Use EIEIO for structured data (chunks, sections)
- Graceful degradation when git-ai unavailable

# Vim Configuration

A practical vim setup for infrastructure management and software development.

## Quick Start

```bash
./setup.sh
```

## Keyboard Shortcuts

### Navigation

| Key | Action |
|-----|--------|
| `Ctrl-n` | Toggle NERDTree file browser |
| `Ctrl-t` | Focus NERDTree |
| `Ctrl-e` | Focus editor (previous pane) |
| `Ctrl-h` | Move to left pane |
| `Ctrl-l` | Move to right pane |

### Files & Buffers

| Key | Action |
|-----|--------|
| `Ctrl-p` | Fuzzy find files |
| `Ctrl-g` | Search in files (ripgrep) |
| `Ctrl-b` | List open buffers |
| `Tab` | Next buffer |
| `Shift-Tab` | Previous buffer |
| `Ctrl-s` | Save file |
| `Ctrl-q` | Close buffer |

### Terminal (Floaterm)

| Key | Action |
|-----|--------|
| `Ctrl-\` | Toggle terminal |
| `Ctrl-n` | New terminal (when in terminal) |
| `Ctrl-q` | Close terminal (when in terminal) |
| `Ctrl-h` | Previous terminal (when in terminal) |
| `Ctrl-l` | Next terminal (when in terminal) |

### Git (Fugitive)

| Command | Action |
|---------|--------|
| `:G` | Git status (interactive) |
| `:Git blame` | Blame current file |
| `:Git diff` | Show diff |
| `:Git commit` | Commit staged changes |
| `:Git push` | Push to remote |
| `:Gdiffsplit` | Side-by-side diff |
| `:Gwrite` | Stage current file |

GitGutter shows `+`, `-`, `~` in the gutter for changes.

### NERDTree

| Key | Action |
|-----|--------|
| `Enter` | Open file/toggle directory |
| `s` | Open in vertical split |
| `i` | Open in horizontal split |
| `t` | Open in new tab |
| `m` | Show menu (create/delete/rename) |
| `cd` | Change vim's working directory to selected |
| `C` | Make selected directory the tree root |
| `u` | Go up one directory |
| `I` | Toggle hidden files |
| `?` | Toggle help |

### General

| Key | Action |
|-----|--------|
| `Esc` | Clear search highlight |
| `u` | Undo |
| `Ctrl-r` | Redo |

### Markdown

| Command | Action |
|---------|--------|
| `:Toc` | Generate table of contents |
| `gx` | Open link under cursor |
| `]]` / `[[` | Jump between headers |

## Features

- **Auto-reload**: Files edited externally (e.g., by Claude) reload automatically
- **Async linting**: ALE runs linters in the background (Go, YAML, Shell)
- **Auto-fix on save**: Trailing whitespace removed, Go files formatted
- **Persistent buffers**: Switch files without saving (`:set hidden`)

## File Types

| Type | Features |
|------|----------|
| Go | gopls, goimports, syntax highlighting |
| YAML | Folding, yamllint |
| Markdown | Syntax highlighting, TOC generation |
| Shell | shellcheck linting |

## Dependencies

- `fzf` - Fuzzy finder (install via package manager)
- `ripgrep` - Fast search (install via package manager)
- `go` 1.24+ - For vim-go binaries (optional)

## Plugin Management

```vim
:PlugInstall    " Install plugins
:PlugUpdate     " Update plugins
:PlugClean      " Remove unused plugins
```

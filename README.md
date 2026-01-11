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

### Fuzzy Search (fzf)

**Finding files with `Ctrl-p`:**
- Start typing to filter files by name/path
- Use `/` to match directory separators (e.g., `src/comp` finds `src/components/`)
- Matches are fuzzy - `abc` matches `a_big_cat.txt`

**Searching content with `Ctrl-g` (ripgrep):**
- Type your search query and press Enter
- Results show `file:line:column:match`
- Continue typing to filter results

**Inside fzf results:**

| Key | Action |
|-----|--------|
| `Enter` | Open file |
| `Ctrl-t` | Open in new tab |
| `Ctrl-x` | Open in horizontal split |
| `Ctrl-v` | Open in vertical split |
| `Ctrl-j/k` | Move up/down in results |
| `Esc` | Cancel |

**Tips:**
- Use `'` prefix for exact match: `'exact`
- Use `^` for prefix match: `^start`
- Use `$` for suffix match: `end$`
- Use `!` to negate: `!node_modules`
- Combine patterns with spaces: `src .js !test`

### Terminal (Floaterm + tmux)

The terminal uses floaterm as a floating window with tmux inside for tab and pane management.

| Key | In Terminal | In Editor |
|-----|-------------|-----------|
| `Ctrl-\` | Hide terminal | Show terminal |
| `Ctrl-t` | New tab | Focus NERDTree |
| `Ctrl-w` | Close pane/tab | (vim default) |
| `Ctrl-h` | Previous tab | Left pane |
| `Ctrl-l` | Next tab | Right pane |
| `Ctrl-s` | Split side-by-side | Save file |
| `Ctrl-j` | Next pane | - |
| `Ctrl-k` | Previous pane | - |

**Features:**
- Terminal opens in vim's current working directory
- New tabs also open in vim's cwd
- Terminal session persists when hidden
- Tabs show in tmux status bar at top
- Split panes for side-by-side terminals
- Mouse click on tabs to switch
- Window names auto-update based on running process

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

| Dependency | Linux (apt) | macOS (brew) |
|------------|-------------|--------------|
| `fzf` | `sudo apt install fzf` | `brew install fzf` |
| `ripgrep` | `sudo apt install ripgrep` | `brew install ripgrep` |
| `tmux` | `sudo apt install tmux` | `brew install tmux` |
| `shellcheck` | `sudo apt install shellcheck` | `brew install shellcheck` |
| `yamllint` | `pip install yamllint` | `pip install yamllint` |
| `go` 1.24+ | [golang.org](https://golang.org/dl/) | `brew install go` |

The setup script will attempt to install missing dependencies automatically.

### macOS Notes

- **Homebrew required**: Install from [brew.sh](https://brew.sh) if not already installed
- **Vim**: macOS ships with an older vim; `brew install vim` recommended for full feature support
- The setup script detects macOS and uses appropriate commands

## Plugin Management

```vim
:PlugInstall    " Install plugins
:PlugUpdate     " Update plugins
:PlugClean      " Remove unused plugins
```

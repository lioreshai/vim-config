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
- Window names auto-update based on the running process; tabs running an AI
  agent get a one-word name instead (see **Agent Tab Names**) and a colour for
  what that agent is doing (see **Agent Tab Status**)

#### Agent Tab Names

Tabs running an interactive CLI agent (`pi`, `claude`, `codex`, ...) are renamed to
a single word, so a window bar full of agent sessions is navigable at a glance
instead of reading `pi pi pi pi`.

- The project directory name is used whenever it is unambiguous, which costs
  nothing and never calls a model.
- A local OpenAI-compatible model server is consulted only when the directory
  says nothing (home dir, scratch, worktree) or when several tabs would collide on
  the same project name. It is shown the sibling tab labels so it can pick
  something that tells them apart.
- Roughly the last 40 screen lines go along as context, with lines matching
  `password|secret|token|api key|private key` dropped first.
- If no model is reachable the tab falls back to the project name, and with no
  project name either it is left exactly as tmux would name it.
- `prefix N` relabels the current tab immediately. A name you set by hand with
  `prefix ,` is respected and never overwritten.

Point it at your own server from `~/.tmux.local`, which is sourced when present
and never written by `setup.sh`:

```tmux
set -g @agent-tab-base-url 'http://127.0.0.1:8000'
set -g @agent-tab-model 'your-model-name'
```

#### Agent Tab Status

Tabs running an agent are coloured by what that agent is doing:

| Colour | Meaning |
|--------|---------|
| green, breathing | working |
| cyan, breathing slowly | idle, but a detached command or backgrounded subagent is still running |
| orange | blocked on you — a permission prompt is open |
| green, solid | the turn finished |
| red | it reported a failure, or died in the middle of a run |

Green and cyan are different instructions to a person: a green tab is busy, a
cyan tab will take input while work continues behind it. The slower breath is
the second channel, so the two stay apart without relying on hue alone.

A tab you have not looked at since it settled **flashes**; visiting it makes the
colour solid. Tabs with no agent in them keep the plain theme.

State comes from the agent itself wherever the agent can say so, because that is
the only source that is never a guess. Both reporters write one line to
`$XDG_CACHE_HOME/tmux-agent-tab/status/<pane-id>`:

```
<running|background|waiting|done|error>	<unix seconds>
```

which is also the script's own writer interface, so anything that knows when it
starts and stops can join in with one line of shell:

```sh
~/.tmux/agent-tab-status.sh set running        # uses $TMUX_PANE
~/.tmux/agent-tab-status.sh set done --pane %7
~/.tmux/agent-tab-status.sh clear
```

**Claude Code** reports through hooks. Merge this into `~/.claude/settings.json`
(keep any hooks already there — each event takes a list):

```json
{
  "hooks": {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "\"$HOME/.tmux/agent-tab-status.sh\" set running 2>/dev/null || true"}]}],
    "PreToolUse":  [{"hooks": [{"type": "command", "command": "\"$HOME/.tmux/agent-tab-status.sh\" set running 2>/dev/null || true"}]}],
    "PostToolUse": [{"hooks": [{"type": "command", "command": "\"$HOME/.tmux/agent-tab-status.sh\" set running 2>/dev/null || true"}]}],
    "Notification": [{"hooks": [{"type": "command", "command": "m=$(jq -r '.message // empty' 2>/dev/null); printf '%s' \"$m\" | grep -qiE 'permission|approve|confirm' && \"$HOME/.tmux/agent-tab-status.sh\" set waiting 2>/dev/null; true"}]}],
    "Stop":       [{"hooks": [{"type": "command", "command": "\"$HOME/.tmux/agent-tab-status.sh\" set done 2>/dev/null || true"}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "\"$HOME/.tmux/agent-tab-status.sh\" clear 2>/dev/null || true"}]}]
  }
}
```

`Notification` fires both for a permission request and for a sixty-second idle
nudge, and the filter above lets only the first one through: treating the nudge
as "waiting" would turn every finished tab orange a minute later and bury the
done colour. `PostToolUse` is there to take the tab back to green after you
approve something.

**pi** reports from an extension (`extensions/tmux-status` in the pi harness
repo) on `agent_start`, `ui_prompt_start`/`ui_prompt_end`, `agent_settled` and
`session_shutdown` — the same transitions. It also reports at `session_start`,
so `/reload` colours the tab straight away instead of leaving it grey until the
session's next turn, and it reports `background` past the end of a turn while a
detached command or a backgrounded subagent is still running — settling means pi
will not continue on its own, not that nothing is happening.

Claude Code has background tasks too, but no hook fires when one ends, so its
tabs never go cyan. Anything that knows can report the state itself with
`agent-tab-status.sh set background`.

An agent that reports nothing falls back to matching cue patterns against the
**bottom eight lines** of the pane, where a TUI keeps its spinner, input box and
footer. That is a guess, and it is bounded on purpose:

- It never paints red. Every phrase that means "this failed" is also a phrase
  agents type all day; reading the whole screen for `Fatal|panic:` painted a tab
  red because the session was *discussing* a panic. `@agent-status-cue-error` is
  there if you have an agent with an unmistakable error line.
- Reported state always wins over a cue.

Red is therefore reserved for two facts: an agent that reported an error, and an
agent that said "running" and then vanished — a crash or a kill, claimed only
for a pane where the agent's process was positively identified first, so an
agent whose process name is not in `@agent-status-pattern` goes stale rather
than red.

Tunable from `~/.tmux.local`:

```tmux
set -g @agent-status-enable 1
set -g @agent-status-pattern '(^|/)(pi|claude|codex|agent|aider)( |$)'
set -g @agent-status-running '#98c379'   # also the breathing colour
set -g @agent-status-waiting '#d79921'
set -g @agent-status-done    '#98c379'
set -g @agent-status-error   '#e06c75'
set -g @agent-status-background '#56b6c2'
set -g @agent-status-dim 30               # percent brightness at the dim end
set -g @agent-status-frame-ms 100         # paint interval while something animates
set -g @agent-status-idle-ms 500          # paint interval when every colour is solid
set -g @agent-status-sample-ms 500        # how often state is re-derived
set -g @agent-status-breathe-ms 3600      # one full breath
set -g @agent-status-background-ms 7200   # one breath of the background colour
set -g @agent-status-blink-ms 1000        # one on/off of an unwatched tab
set -g @agent-status-alert-style blink    # or 'pulse' to fade instead of blink
set -g @agent-status-probe-ms 3000        # how often to read an unreporting pane
set -g @agent-status-cue-lines 8
```

The breath is a cosine over a brightness ramp whose step count is derived from
`frame-ms` and `breathe-ms`, so the two can be set to anything and the motion
stays even — with a quarter-frame of margin, because a frame that arrives late
should repeat a step rather than skip one. Skipping is what stuttering is. Each
frame also sleeps only the time it has left, since painting takes real time and
adding it to the sleep is the other way the phase drifts.

An unwatched tab blinks rather than breathes on purpose: a breathing green
"done" and a breathing green "running" look the same at a glance, while a hard
on/off is unmistakably an alert. `@agent-status-alert-style pulse` trades that
apart-ness for a smoother look.

`prefix S` clears every tab back to the theme. One `tmux` call per frame, only
for windows whose colour actually changed, and state sampling runs on its own
slower clock so a smooth fade does not mean re-reading every pane ten times a
second: 1.7% of one core while a tab is animating, and one call every half
second when the bar is all solid. `./agent-tab-status-test.sh` runs 23 checks
against a throwaway session, including that a breath moves through at least ten
shades with no visible jump between frames.

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
| `jq` | `sudo apt install jq` | `brew install jq` |
| `shellcheck` | `sudo apt install shellcheck` | `brew install shellcheck` |
| `yamllint` | `pip install yamllint` | `pip install yamllint` |
| `go` 1.24+ | [golang.org](https://golang.org/dl/) | `brew install go` |

The setup script will attempt to install missing dependencies automatically.

### macOS Notes

- **Homebrew required**: Install from [brew.sh](https://brew.sh) if not already installed
- **Vim**: macOS ships with an older vim; `brew install vim` recommended for full feature support
- The setup script detects macOS and uses appropriate commands
- **Tab naming**: `flock` is not available on macOS, so the namer deduplicates
  with a pidfile instead; `sha1sum` falls back to `shasum`

## Plugin Management

```vim
:PlugInstall    " Install plugins
:PlugUpdate     " Update plugins
:PlugClean      " Remove unused plugins
```

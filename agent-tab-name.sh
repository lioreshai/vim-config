#!/usr/bin/env bash
# Label tmux windows that run an interactive agent (pi, claude, codex, ...)
# with a single word, so tabs are navigable instead of showing "pi pi pi".
#
# Default label is the project directory name. A local OpenAI-compatible model
# server is consulted only where it adds signal: when the directory says nothing
# (home dir, scratch, worktree) or when several agent tabs would collide on the
# same project name.
#
# Fallback: if the model is unreachable or answers junk, the label stays as the
# project name; if even that is unknown the window is left untouched, so tmux
# automatic-rename keeps showing the command name (today's behaviour).
#
# usage: agent-tab-name.sh [--tick] [--watch] [--force] [--force-current] [--dry-run]

set -uo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-tab"
LOCK="$STATE_DIR/.tick.lock"
WATCH_PID="$STATE_DIR/.watch.pid"
mkdir -p "$STATE_DIR"

HAVE_FLOCK=0
command -v flock >/dev/null 2>&1 && HAVE_FLOCK=1

opt() { tmux show-options -g -v "$1" 2>/dev/null || true; }

BASE_URL="${AGENT_TAB_BASE_URL:-$(opt @agent-tab-base-url)}"
MODEL="${AGENT_TAB_MODEL:-$(opt @agent-tab-model)}"
PATTERN="${AGENT_TAB_PATTERN:-$(opt @agent-tab-pattern)}"
GENERIC="${AGENT_TAB_GENERIC:-$(opt @agent-tab-generic)}"
TTL="${AGENT_TAB_TTL:-$(opt @agent-tab-ttl)}"
INTERVAL="${AGENT_TAB_INTERVAL:-$(opt @agent-tab-interval)}"
REDACT="${AGENT_TAB_REDACT:-$(opt @agent-tab-redact)}"
: "${BASE_URL:=http://127.0.0.1:8000}"
[ -z "$PATTERN" ] && PATTERN='(^|/)(pi|claude|codex|agent|aider)( |$)'
[ -z "$GENERIC" ] && GENERIC='^(home|users|tmp|var|srv|root|projects?|repos?|src|work|worktrees?|scratch|dev|tmp[0-9]*)$'
[ -z "$REDACT" ] && REDACT='password|passwd|secret|token|api[_-]?key|authorization|bearer|private key|BEGIN [A-Z]* PRIVATE'
[ -z "$PATTERN" ] && PATTERN='(^|/)(pi|claude|codex|agent|aider)( |$)'
[ -z "$GENERIC" ] && GENERIC='^(home|users|tmp|var|srv|root|projects?|repos?|src|work|worktrees?|scratch|dev|tmp[0-9]*)$'
: "${TTL:=180}"
: "${INTERVAL:=5}"

MODE=tick
DRY=0
for arg in "$@"; do
  case "$arg" in
    --watch) MODE=watch ;;
    --force) MODE=force ;;
    --force-current) MODE=force-current ;;
    --dry-run) DRY=1 ;;
  esac
done

command -v tmux >/dev/null 2>&1 || exit 0
tmux list-sessions >/dev/null 2>&1 || exit 0

rename_win() { # window_id label
  if [ "$DRY" = 1 ]; then
    echo "would rename $1 -> $2"
  else
    tmux rename-window -t "$1" "$2" 2>/dev/null
  fi
}

strip_ansi() { LC_ALL=C sed -e 's/[[:cntrl:]]\[[0-9;?]*[a-zA-Z]//g' -e 's/[[:cntrl:]][()][ABMN]//g'; }

sanitize() { # -> one lowercase [a-z0-9._-] token, max 14 chars
  tr 'A-Z' 'a-z' | tr -c 'a-z0-9._-' ' ' | awk '{ print $1 }' | cut -c1-14
}

hash_text() { # GNU or BSD checksums
  if command -v sha1sum >/dev/null 2>&1; then sha1sum | cut -d' ' -f1; else shasum | cut -d' ' -f1; fi
}

file_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

run_locked() { # one tick at a time, shared between watcher and manual runs
  if [ "$HAVE_FLOCK" = 1 ]; then
    (
      exec 9>"$LOCK"
      flock -w 10 9 && tick
    )
  else
    tick
  fi
}

# no model configured: use the first one the server advertises
detect_model() {
  local cache="$STATE_DIR/.model" id
  if [ -f "$cache" ] && [ $(( $(date +%s) - $(file_mtime "$cache") )) -lt 3600 ]; then
    cat "$cache"
    return
  fi
  id=$(curl -fsS -m 4 "$BASE_URL/v1/models" 2>/dev/null | jq -r '.data[0].id // empty' 2>/dev/null)
  [ -n "$id" ] && printf '%s' "$id" >"$cache"
  printf '%s' "$id"
}

ask_model() { # cwd screen siblings current_label
  local cwd="$1" screen="$2" siblings="$3" current="$4" reply
  [ -z "$MODEL" ] && MODEL="$(detect_model)"
  [ -z "$MODEL" ] && return 0
  reply="$(jq -n \
      --arg model "$MODEL" --arg cwd "$cwd" --arg ctx "$screen" \
      --arg sib "$siblings" --arg cur "$current" \
      '{model:$model,messages:[{role:"user",content:
        ("Pick one short label for this terminal tab.\n"
        + "Rules: exactly one token, lowercase, only a-z 0-9 . _ -, max 14 chars,"
        + " no spaces, no explanation, no trailing punctuation.\n"
        + "Sibling tabs are labelled: " + $sib + ". Pick something that tells this tab"
        + " apart from them, naming the specific task or sub-project.\n"
        + "This tab is currently labelled: " + $cur + ". Keep that unless the screen"
        + " shows the work has clearly moved on.\n"
        + "Ignore project names that appear only as examples in the conversation.\n\n"
        + "cwd: " + $cwd + "\nscreen (credentials redacted):\n" + $ctx)}],
        max_tokens:16,temperature:0,chat_template_kwargs:{enable_thinking:false}}' 2>/dev/null \
    | curl -fsS -m 6 "$BASE_URL/v1/chat/completions" -H 'content-type: application/json' -d @- 2>/dev/null \
    | jq -r '.choices[0].message.content // empty' 2>/dev/null)"
  printf '%s' "${reply##*
}" | sanitize
}

watcher_alive() { # pid -> 0 if that pid is still a watcher of ours
  local pid="$1"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if [ -r "/proc/$pid/cmdline" ]; then        # Linux: be precise about PID reuse
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "agent-tab-name" || return 1
  fi
  return 0
}

watch() {
  # Deduplicated by pidfile, deliberately not by file lock: a lock fd is
  # inherited by children (sleep, curl), so a killed watcher's leftovers would
  # keep holding it and every later watcher would exit thinking one is alive.
  local pid=""
  [ -f "$WATCH_PID" ] && pid=$(cat "$WATCH_PID" 2>/dev/null)
  watcher_alive "$pid" && exit 0
  printf '%s\n' "$$" >"$WATCH_PID"

  while :; do
    tmux list-sessions >/dev/null 2>&1 || exit 0
    run_locked
    sleep "$INTERVAL"
  done
}

tick() {
  local pid win wname cmd path dead base
  local -a P_ID P_WIN P_NAME P_CMD P_BASE P_PATH
  P_ID=(); P_WIN=(); P_NAME=(); P_CMD=(); P_BASE=(); P_PATH=()

  while IFS=$'\t' read -r pid win wname cmd path dead; do
    [ "$dead" = "1" ] && continue
    [[ "$cmd" =~ $PATTERN ]] || continue
    base=$(basename "${path:-/}" | tr 'A-Z' 'a-z')
    [ "$path" = "$HOME" ] && base=""
    [[ "$base" =~ $GENERIC ]] && base=""
    P_ID+=("$pid"); P_WIN+=("$win"); P_NAME+=("$wname"); P_CMD+=("$cmd"); P_BASE+=("$base"); P_PATH+=("$path")
  done < <(tmux list-panes -a -F $'#{pane_id}\t#{window_id}\t#{window_name}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_dead}')

  local current_window=""
  [ "$MODE" = force-current ] && current_window="$(tmux display-message -p '#{window_id}')"

  local -A base_count=()
  for base in "${P_BASE[@]}"; do
    [ -n "$base" ] && base_count["$base"]=$(( ${base_count["$base"]:-0} + 1 ))
  done

  local now file last_ts last_hash last_label screen hash dup siblings label
  now=$(date +%s)

  local i j
  for i in "${!P_ID[@]}"; do
    pid="${P_ID[$i]}"; win="${P_WIN[$i]}"; wname="${P_NAME[$i]}"
    cmd="${P_CMD[$i]}"; base="${P_BASE[$i]}"; path="${P_PATH[$i]}"
    [ -n "$current_window" ] && [ "$win" != "$current_window" ] && continue

    file="$STATE_DIR/$pid"
    last_ts=0; last_hash=""; last_label=""
    [ -f "$file" ] && IFS=$'\t' read -r last_ts last_hash last_label <"$file"
    last_ts=${last_ts:-0}

    # a name that is neither our label nor the auto command name was set by hand
    if [ -n "$last_label" ] && [ "$wname" != "$last_label" ] && [ "$wname" != "$cmd" ] \
       && [ "$MODE" != force ] && [ "$MODE" != force-current ]; then
      continue
    fi

    # an unambiguous project directory needs no model
    dup=0
    [ -n "$base" ] && dup=${base_count[$base]:-0}
    if [ -n "$base" ] && [ "$dup" -le 1 ]; then
      printf '%s\t%s\t%s\n' "$now" "-" "$base" >"$file"
      [ "$wname" != "$base" ] && rename_win "$win" "$base"
      continue
    fi

    screen="$(tmux capture-pane -p -t "$pid" 2>/dev/null \
      | strip_ansi \
      | grep -viE "$REDACT" \
      | tail -n 40)"
    hash=$(printf '%s' "$screen" | hash_text)

    # relabel only when the screen changed and the previous attempt is old enough
    local refresh=0
    case "$MODE" in force|force-current) refresh=1 ;; esac
    [ "$refresh" = 0 ] && [ -n "$last_hash" ] && [ "$hash" != "$last_hash" ] \
      && [ $((now - last_ts)) -ge "$TTL" ] && refresh=1
    # first ever look at this pane
    [ "$refresh" = 0 ] && [ "${last_ts:-0}" -eq 0 ] && refresh=1

    if [ "$refresh" = 0 ]; then
      if [ -n "$last_label" ] && [ "$wname" != "$last_label" ]; then
        rename_win "$win" "$last_label"
      elif [ -z "$last_label" ] && [ -n "$base" ] && [ "$wname" != "$base" ]; then
        rename_win "$win" "$base"
      fi
      printf '%s\t%s\t%s\n' "$now" "$last_hash" "$last_label" >"$file"
      continue
    fi

    siblings="$(
      for j in "${!P_NAME[@]}"; do
        [ "$j" = "$i" ] && continue
        printf '%s\n' "${P_NAME[$j]}"
      done | sort -u | paste -sd' ' -
    )"
    label=$(ask_model "${path/#$HOME/~}" "$screen" "${siblings:-none}" "${last_label:-none}")
    case "$label" in
      ""|none|nil|null|unknown|project|terminal|code|pi|claude|codex|tmux|shell|home) label="" ;;
    esac

    if [ -n "$label" ]; then
      printf '%s\t%s\t%s\n' "$now" "$hash" "$label" >"$file"
      rename_win "$win" "$label"
    else
      # model unreachable: fall back to the project name if we have one, else
      # leave the pane to tmux automatic-rename and back off until TTL expires
      printf '%s\t%s\t%s\n' "$now" "" "" >"$file"
      [ -n "$base" ] && [ "$wname" != "$base" ] && rename_win "$win" "$base"
    fi
  done

  # forget panes that went away
  local live f
  live=" $(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr '\n' ' ') "
  shopt -s nullglob
  for f in "$STATE_DIR"/*; do
    case "$f" in */.*) continue ;; esac
    case "$live" in *" ${f##*/} "*) ;; *) rm -f "$f" ;; esac
  done
  shopt -u nullglob
}

if [ "$MODE" = watch ]; then
  watch
else
  run_locked
fi

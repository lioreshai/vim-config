#!/usr/bin/env bash
# Colour tmux tabs by what the agent inside them is doing.
#
#   running   green, breathing      the agent is working
#   waiting   orange                it is blocked on you (permission, question)
#   done      green, solid          the turn finished
#   error     red                   it failed, or died in the middle of a run
#
# A tab you have not looked at since it reached waiting/done/error flashes;
# visiting it makes the colour solid. Tabs without an agent are left alone.
#
# State comes from the agent itself wherever the agent can say so, because that
# is the only source that is never a guess:
#
#   pi      extensions/tmux-status  (agent_start / ui_prompt_start / agent_settled)
#   claude  hooks in ~/.claude/settings.json (UserPromptSubmit, PreToolUse,
#           Notification, Stop, SessionEnd)
#
# Both write one line to $XDG_CACHE_HOME/tmux-agent-tab/status/<pane-id>:
#
#   <running|waiting|done|error>\t<unix seconds>
#
# which is also this script's own writer interface, so anything else that knows
# when it starts and stops can join in with one line of shell:
#
#   agent-tab-status.sh set running        # uses $TMUX_PANE
#   agent-tab-status.sh set done --pane %7
#   agent-tab-status.sh clear
#
# For an agent that reports nothing, the last 40 screen lines are matched
# against the cue patterns below. That is a fallback and it is guessing: an
# agent whose UI changes changes the answer. Reported state always wins.
#
# usage: agent-tab-status.sh [--watch|--tick|--dump] [--frames N] [--dry-run]
#        agent-tab-status.sh set <running|waiting|done|error> [--pane %N]
#        agent-tab-status.sh clear [--pane %N] | clear-all

set -uo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-tab"
STATUS_DIR="$STATE_DIR/status"
WATCH_PID="$STATE_DIR/.status.pid"
mkdir -p "$STATUS_DIR"

now() { printf '%s' "${EPOCHSECONDS:-$(date +%s)}"; }

# ---------------------------------------------------------------- writer mode
# Kept above every tmux call: reporters run in the agent's hot path (one per
# tool call for claude) and must not pay for a tmux round trip.
write_state() { # state pane
  local state="$1" pane="$2"
  [ -n "$pane" ] || { echo "no pane: pass --pane or run inside tmux" >&2; return 2; }
  case "$state" in
    clear) rm -f "$STATUS_DIR/$pane"; return 0 ;;
    running | waiting | done | error) ;;
    *) echo "unknown state: $state" >&2; return 2 ;;
  esac
  printf '%s\t%s\n' "$state" "$(now)" >"$STATUS_DIR/$pane"
}

MODE=tick
DRY=0
FRAMES=1
ARG_PANE="${TMUX_PANE:-}"
SET_STATE=""
prev=""
for arg in "$@"; do
  case "$prev" in
    --pane) ARG_PANE="$arg"; prev=""; continue ;;
    --frames) FRAMES="$arg"; prev=""; continue ;;
  esac
  case "$arg" in
    --watch) MODE=watch ;;
    --tick) MODE=tick ;;
    --frames) prev=--frames ;;
    --dump) MODE=dump ;;
    --dry-run) DRY=1 ;;
    --pane) prev=--pane ;;
    set) MODE=set ;;
    clear) MODE=set; SET_STATE=clear ;;
    clear-all) MODE=clear-all ;;
    running | waiting | done | error) SET_STATE="$arg" ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [ "$MODE" = set ]; then
  write_state "${SET_STATE:-}" "$ARG_PANE"
  exit $?
fi
command -v tmux >/dev/null 2>&1 || exit 0
tmux list-sessions >/dev/null 2>&1 || exit 0

# Hand every window back to the theme. A painter that was killed leaves its last
# frame on the bar with nothing left running to take it back, so a fresh painter
# starts by clearing everything rather than inheriting colours it cannot explain.
unpaint_all() {
  local win batch=()
  while read -r win; do
    [ -n "$win" ] || continue
    batch+=(set -wu -t "$win" @agent-tab-color ';' set -wu -t "$win" @agent-tab-color-cur ';')
  done < <(tmux list-windows -a -F '#{window_id}' 2>/dev/null)
  [ ${#batch[@]} = 0 ] && return 0
  batch+=(refresh-client -S)
  tmux "${batch[@]}" 2>/dev/null
}

if [ "$MODE" = clear-all ]; then
  rm -f "$STATUS_DIR"/* 2>/dev/null
  unpaint_all
  exit 0
fi

# ---------------------------------------------------------------- config
opt() { tmux show-options -gv "$1" 2>/dev/null || true; }

ENABLED="${AGENT_STATUS_ENABLE:-$(opt @agent-status-enable)}"
PATTERN="${AGENT_STATUS_PATTERN:-$(opt @agent-status-pattern)}"
C_RUNNING="$(opt @agent-status-running)"
C_WAITING="$(opt @agent-status-waiting)"
C_DONE="$(opt @agent-status-done)"
C_ERROR="$(opt @agent-status-error)"
DIM_PCT="$(opt @agent-status-dim)"
FRAME_MS="$(opt @agent-status-frame-ms)"
IDLE_MS="$(opt @agent-status-idle-ms)"
SAMPLE_MS="$(opt @agent-status-sample-ms)"
BREATHE_MS="$(opt @agent-status-breathe-ms)"
BLINK_MS="$(opt @agent-status-blink-ms)"
PROBE_MS="$(opt @agent-status-probe-ms)"
ALERT_STYLE="$(opt @agent-status-alert-style)"
CUE_RUNNING="$(opt @agent-status-cue-running)"
CUE_WAITING="$(opt @agent-status-cue-waiting)"
CUE_ERROR="$(opt @agent-status-cue-error)"
TAIL_LINES="$(opt @agent-status-cue-lines)"
REDACT="${AGENT_TAB_REDACT:-$(opt @agent-tab-redact)}"

: "${ENABLED:=1}"
[ -z "$PATTERN" ] && PATTERN='(^|/)(pi|claude|codex|agent|aider)( |$)'
[ -z "$C_RUNNING" ] && C_RUNNING='#98c379'
[ -z "$C_WAITING" ] && C_WAITING='#d79921'
[ -z "$C_DONE" ] && C_DONE='#98c379'
[ -z "$C_ERROR" ] && C_ERROR='#e06c75'
: "${DIM_PCT:=30}"
# Animation is wall-clock, not frame-counted: the phase comes from the time of
# day, so a late frame skips ahead instead of stretching the cycle, and the
# paint rate can change without changing the tempo.
: "${FRAME_MS:=100}"        # paint interval while something is animating
: "${IDLE_MS:=500}"         # paint interval when every colour is solid
: "${SAMPLE_MS:=500}"       # how often state is re-derived, independent of paint
: "${BREATHE_MS:=3600}"     # one full breath
: "${BLINK_MS:=1000}"       # one on/off of an unwatched tab
: "${PROBE_MS:=3000}"       # how often an unreporting pane's screen is read
[ -z "$ALERT_STYLE" ] && ALERT_STYLE=blink
# Only the bottom of the pane, because that is where a TUI keeps its spinner,
# its input box and its footer. Reading the whole screen reads the conversation,
# and a conversation about a crash is not a crash.
: "${TAIL_LINES:=8}"
# "esc to interrupt" is claude's own working indicator; the rest are the usual
# shapes of a question. Cues, not contracts.
#
# There is deliberately no error cue. Every phrase that means "this failed" is
# also a phrase agents type all day: the first draft matched "Fatal|panic:|API
# Error" and painted a tab red because that session was discussing a panic. Red
# is reserved for what the agent reports and for a run that died, both of which
# are facts rather than readings. @agent-status-cue-error exists for anyone with
# an agent that has an unmistakable error line.
[ -z "$CUE_RUNNING" ] && CUE_RUNNING='esc to interrupt|Thinking…|Working…|Running…'
[ -z "$CUE_WAITING" ] && CUE_WAITING='Do you want|Would you like|\[y/N\]|\(y/n\)|❯ 1\.|1\. Yes'
[ -z "$REDACT" ] && REDACT='password|passwd|secret|token|api[_-]?key|authorization|bearer|private key|BEGIN [A-Z]* PRIVATE'

[ "$ENABLED" = 0 ] && exit 0

# ---------------------------------------------------------------- colour math
HEX_OUT=""
scale_hex() { # #rrggbb pct -> $HEX_OUT, scaled toward black. No $( ): this runs
  local h="${1#\#}" p="$2"            # per window per frame and a fork per call
  printf -v HEX_OUT '#%02x%02x%02x' \
    $(( 0x${h:0:2} * p / 100 )) $(( 0x${h:2:2} * p / 100 )) $(( 0x${h:4:2} * p / 100 ))
}

# A breath is a cosine, not a sawtooth: brightness lingers at the ends and moves
# fastest through the middle, which is what reads as breathing rather than as a
# level meter.
#
# The ramp has exactly one step per painted frame. Getting this wrong is what
# made the first version look uneven: 24 steps over 2.4s is a step every 100ms,
# painted every 120ms, so every fifth frame skipped a step and the jump was
# double the others. Deriving it means frame-ms and breathe-ms can be set to
# anything and the motion stays even.
# ...with a quarter of a frame in hand, so a frame that arrives late repeats a
# step instead of skipping one. Repeating is invisible; skipping is the stutter.
STEPS=$(( BREATHE_MS * 4 / (FRAME_MS * 5) ))
[ "$STEPS" -lt 8 ] && STEPS=8
[ "$STEPS" -gt 64 ] && STEPS=64
declare -a PCTS=() RAMP=()
build_ramp() {
  local pct
  while read -r pct; do
    PCTS+=("$pct")
    scale_hex "$C_RUNNING" "$pct"
    RAMP+=("$HEX_OUT")
  done < <(awk -v n="$STEPS" -v dim="$DIM_PCT" 'BEGIN {
    for (i = 0; i < n; i++) printf "%d\n", dim + (100 - dim) * (1 - cos(2 * 3.14159265 * i / n)) / 2
  }')
}
build_ramp
nap_for() { # target_ms started_ms -> sleeps whatever is left of the frame
  local rest=$(( $1 - (NOW_MS - $2) ))
  [ "$rest" -lt 5 ] && rest=5
  local nap
  printf -v nap '%d.%03d' "$(( rest / 1000 ))" "$(( rest % 1000 ))"
  sleep "$nap"
}
scale_hex "$C_WAITING" "$DIM_PCT"; DIM_WAITING="$HEX_OUT"
scale_hex "$C_DONE" "$DIM_PCT";    DIM_DONE="$HEX_OUT"
scale_hex "$C_ERROR" "$DIM_PCT";   DIM_ERROR="$HEX_OUT"

NOW_MS=0
if [ -n "${EPOCHREALTIME:-}" ]; then
  now_ms() { # bash 5: no fork at all, which is the whole point at 8 frames a second
    local t="${EPOCHREALTIME/,/.}"
    NOW_MS=$(( ${t%.*} * 1000 + 10#${t#*.} / 1000 ))
  }
else
  now_ms() { NOW_MS=$(( $(date +%s%3N) )); }
fi

# Urgency, for a window whose panes disagree. A table, not a function: this is
# read twice per pane per sample and $( ) would fork for every read.
declare -A RANK=([error]=4 [waiting]=3 [running]=2 [done]=1)

COLOR=""
phase_color() { # state unseen -> $COLOR ("" leaves the theme alone)
  local base="" dim="" idx
  case "$1" in
    running)
      COLOR="${RAMP[$(( (NOW_MS % BREATHE_MS) * STEPS / BREATHE_MS ))]}"
      return ;;
    waiting) base="$C_WAITING"; dim="$DIM_WAITING" ;;
    done)    base="$C_DONE";    dim="$DIM_DONE" ;;
    error)   base="$C_ERROR";   dim="$DIM_ERROR" ;;
    *) COLOR=""; return ;;
  esac
  if [ "$2" != 1 ]; then COLOR="$base"; return; fi
  # An unwatched tab blinks rather than breathes, and that is deliberate: a
  # breathing green "done" and a breathing green "running" are the same thing to
  # a glance, while a hard on/off is unmistakably an alert. @agent-status-alert-
  # style pulse trades that apart-ness for a smoother look.
  if [ "$ALERT_STYLE" = pulse ]; then
    idx=$(( (NOW_MS % BLINK_MS) * STEPS / BLINK_MS ))
    scale_hex "$base" "${PCTS[$idx]}"
    COLOR="$HEX_OUT"
  elif [ $(( NOW_MS % BLINK_MS )) -lt $(( BLINK_MS / 2 )) ]; then
    COLOR="$base"
  else
    COLOR="$dim"
  fi
}

declare -A DERIVED=()   # pane -> state the screen cues last showed
declare -A SAW_AGENT=() # pane -> 1 once an agent was positively seen running in it
declare -A UNSEEN=()    # window -> 1 while you have not looked since it settled
declare -A PAINTED=()   # window -> colour currently set, so we only write changes
declare -A LAST=()      # window -> state in the previous frame, to spot a settle

strip_ansi() { LC_ALL=C sed -e 's/[[:cntrl:]]\[[0-9;?]*[a-zA-Z]//g' -e 's/[[:cntrl:]][()][ABMN]//g'; }

probe_screen() { # pane -> state from screen cues
  local screen
  screen="$(tmux capture-pane -p -t "$1" 2>/dev/null | strip_ansi | grep -viE "$REDACT" | tail -n "$TAIL_LINES")"
  [ -z "$screen" ] && { printf ''; return; }
  if [ -n "$CUE_ERROR" ] && printf '%s' "$screen" | grep -qiE "$CUE_ERROR"; then printf 'error'
  elif [ -n "$CUE_WAITING" ] && printf '%s' "$screen" | grep -qiE "$CUE_WAITING"; then printf 'waiting'
  elif [ -n "$CUE_RUNNING" ] && printf '%s' "$screen" | grep -qiE "$CUE_RUNNING"; then printf 'running'
  else printf ''
  fi
}

# State and appearance are separated because they change at different rates: a
# breath needs a new colour eight times a second, while what the agent is doing
# changes twice a second at most and costs a tmux round trip plus, for an
# unreporting pane, a screen capture to find out.
declare -A WIN_STATE=() WIN_SEEN=()
ANIMATING=0
LAST_PROBE=0
LAST_PRUNE=0

sample() { # -> WIN_STATE, WIN_SEEN, UNSEEN, ANIMATING
  local pane win cmd dead active attached pstate wstate probe=0
  WIN_STATE=(); WIN_SEEN=()
  if [ $(( NOW_MS - LAST_PROBE )) -ge "$PROBE_MS" ]; then probe=1; LAST_PROBE=$NOW_MS; fi

  while IFS=$'\t' read -r pane win cmd dead active attached; do
    [ "$dead" = 1 ] && continue
    pstate=""
    local file="$STATUS_DIR/$pane" reported="" ts=""
    [ -f "$file" ] && IFS=$'\t' read -r reported ts <"$file" 2>/dev/null
    local present=0
    if [[ "$cmd" =~ $PATTERN ]]; then present=1; SAW_AGENT[$pane]=1; fi

    if [ -n "$reported" ]; then
      if [ "$present" = 1 ] || [ "$reported" != running ] || [ "${SAW_AGENT[$pane]:-0}" != 1 ]; then
        pstate="$reported"
      else
        # It said "running" and the process we watched it in is gone, so it never
        # got to say how it ended: a crash or a kill. Only claimed for a pane
        # where an agent was positively identified, so an agent whose process
        # name is not in the pattern stays merely stale instead of going red.
        # Recorded, so the next sample reads the verdict back instead of
        # re-deriving it.
        pstate=error
        printf '%s\t%s\n' error "$(now)" >"$file"
      fi
    elif [ "$present" = 1 ]; then
      if [ "$probe" = 1 ]; then
        pstate="$(probe_screen "$pane")"
        # a screen that stopped showing work has finished it
        [ -z "$pstate" ] && [ "${DERIVED[$pane]:-}" = running ] && pstate=done
        DERIVED[$pane]="$pstate"
      else
        pstate="${DERIVED[$pane]:-}"
      fi
    fi

    [ -n "$pstate" ] || continue
    if [ "${RANK[$pstate]:-0}" -gt "${RANK[${WIN_STATE[$win]:-}]:-0}" ]; then WIN_STATE[$win]="$pstate"; fi
    [ "$active" = 1 ] && [ "${attached:-0}" != 0 ] && WIN_SEEN[$win]=1
  done < <(tmux list-panes -a -F \
    $'#{pane_id}\t#{window_id}\t#{pane_current_command}\t#{pane_dead}\t#{window_active}\t#{session_attached}')

  ANIMATING=0
  for win in "${!WIN_STATE[@]}"; do
    wstate="${WIN_STATE[$win]}"
    if [ "${WIN_SEEN[$win]:-0}" = 1 ]; then
      UNSEEN[$win]=0                     # you are looking at it right now
    elif [ "$wstate" != running ] && [ "$wstate" != "${LAST[$win]:-}" ]; then
      UNSEEN[$win]=1                     # it just settled, and not in front of you
    fi
    LAST[$win]="$wstate"
    if [ "$wstate" = running ] || [ "${UNSEEN[$win]:-0}" = 1 ]; then ANIMATING=1; fi
  done

  if [ $(( NOW_MS - LAST_PRUNE )) -ge 60000 ]; then
    LAST_PRUNE=$NOW_MS
    local live f
    live=" $(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr '\n' ' ') "
    shopt -s nullglob
    for f in "$STATUS_DIR"/*; do
      case "$live" in *" ${f##*/} "*) ;; *) rm -f "$f" ;; esac
    done
    shopt -u nullglob
  fi
}

render() { # frame -> at most one batched tmux call
  local frame="$1" win
  local -a batch=() changes=()

  for win in "${!WIN_STATE[@]}"; do
    phase_color "${WIN_STATE[$win]}" "${UNSEEN[$win]:-0}"
    [ "$COLOR" = "${PAINTED[$win]:-}" ] && continue
    PAINTED[$win]="$COLOR"
    changes+=("$win $COLOR")
    batch+=(set -w -t "$win" @agent-tab-color "$COLOR" ';')
    batch+=(set -w -t "$win" @agent-tab-color-cur "$COLOR" ';')
  done

  # a window that lost its agent goes back to the theme
  for win in "${!PAINTED[@]}"; do
    [ -n "${WIN_STATE[$win]:-}" ] && continue
    unset "PAINTED[$win]" "UNSEEN[$win]" "LAST[$win]"
    changes+=("$win -")
    batch+=(set -wu -t "$win" @agent-tab-color ';')
    batch+=(set -wu -t "$win" @agent-tab-color-cur ';')
  done

  [ ${#batch[@]} = 0 ] && return 0
  if [ "$DRY" = 1 ]; then
    local ch
    for ch in "${changes[@]}"; do printf 'frame %s %s\n' "$frame" "$ch"; done
    return 0
  fi
  batch+=(refresh-client -S)
  tmux "${batch[@]}" 2>/dev/null
}

dump() {
  local pane win cmd dead active attached reported ts
  printf '%-6s %-5s %-10s %-8s %s\n' pane window command reported screen
  while IFS=$'\t' read -r pane win cmd dead active attached; do
    [[ "$cmd" =~ $PATTERN ]] || [ -f "$STATUS_DIR/$pane" ] || continue
    reported=""; ts=""
    [ -f "$STATUS_DIR/$pane" ] && IFS=$'\t' read -r reported ts <"$STATUS_DIR/$pane" 2>/dev/null
    printf '%-6s %-5s %-10s %-8s %s\n' "$pane" "$win" "$cmd" "${reported:--}" "$(probe_screen "$pane")"
  done < <(tmux list-panes -a -F \
    $'#{pane_id}\t#{window_id}\t#{pane_current_command}\t#{pane_dead}\t#{window_active}\t#{session_attached}')
}

watcher_alive() {
  local pid="$1"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if [ -r "/proc/$pid/cmdline" ]; then
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "agent-tab-status" || return 1
  fi
  return 0
}

case "$MODE" in
  dump) dump ;;
  tick)
    frame=0
    while [ "$frame" -lt "$FRAMES" ]; do
      now_ms
      started=$NOW_MS
      sample
      render "$frame"
      frame=$(( frame + 1 ))
      if [ "$frame" -lt "$FRAMES" ]; then now_ms; nap_for "$FRAME_MS" "$started"; fi
    done
    ;;
  watch)
    pid=""
    [ -f "$WATCH_PID" ] && pid=$(cat "$WATCH_PID" 2>/dev/null)
    watcher_alive "$pid" && exit 0
    printf '%s\n' "$$" >"$WATCH_PID"
    unpaint_all
    frame=0
    last_sample=0
    while :; do
      tmux list-sessions >/dev/null 2>&1 || exit 0
      now_ms
      started=$NOW_MS
      if [ $(( NOW_MS - last_sample )) -ge "$SAMPLE_MS" ]; then
        sample
        last_sample=$NOW_MS
      fi
      render "$frame"
      frame=$(( frame + 1 ))
      # Paint fast only while there is something to animate. A bar of solid
      # colours costs one tmux call every half second, the same as before.
      now_ms
      if [ "$ANIMATING" = 1 ]; then nap_for "$FRAME_MS" "$started"; else nap_for "$IDLE_MS" "$started"; fi
    done
    ;;
esac

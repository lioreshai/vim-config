#!/usr/bin/env bash
# Checks agent-tab-status.sh against a throwaway tmux session.
#
# Everything runs with --dry-run and an isolated XDG_CACHE_HOME, so no tab you
# are looking at is repainted and no real reporter state is touched. The session
# name is deliberately unlike anything a person would open.
#
#   ./agent-tab-status-test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/agent-tab-status.sh"
SESSION="agent-tab-selftest-$$"
CACHE="$(mktemp -d "${TMPDIR:-/tmp}/agent-tab-selftest.XXXXXX")"
export XDG_CACHE_HOME="$CACHE"
STATUS="$CACHE/tmux-agent-tab/status"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }
is() { # label expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 — expected [$2], got [$3]"; fi
}
has() { # label needle haystack
  case "$3" in *"$2"*) ok "$1" ;; *) bad "$1 — [$2] missing from: $3" ;; esac
}
hasnt() { # label needle haystack
  case "$3" in *"$2"*) bad "$1 — [$2] should not appear" ;; *) ok "$1" ;; esac
}

cleanup() { tmux kill-session -t "$SESSION" 2>/dev/null; rm -rf "$CACHE"; }
trap cleanup EXIT

command -v tmux >/dev/null 2>&1 || { echo "tmux not installed"; exit 0; }
tmux list-sessions >/dev/null 2>&1 || { echo "no tmux server running"; exit 0; }

# ------------------------------------------------------------------ fixtures
tmux new-session -d -s "$SESSION" -n w-run 'sleep 600'
tmux new-window -t "$SESSION" -n w-wait 'sleep 600'
tmux new-window -t "$SESSION" -n w-err 'sleep 600'
mkdir -p "$STATUS"

win() { tmux list-windows -t "$SESSION" -F '#{window_id} #{window_name}' | awk -v n="$1" '$2==n{print $1}'; }
pane() { tmux list-panes -t "$SESSION:$1" -F '#{pane_id}' | head -1; }

W_RUN=$(win w-run); W_WAIT=$(win w-wait); W_ERR=$(win w-err)
P_RUN=$(pane w-run); P_WAIT=$(pane w-wait); P_ERR=$(pane w-err)

report() { printf '%s\t%s\n' "$2" "$(date +%s)" >"$STATUS/$1"; }
colors_for() { # window output -> the colours it was painted, in order
  printf '%s\n' "$2" | awk -v w="$1" '$3 == w { print $4 }'
}

# The test session is detached, so every window in it counts as unwatched.
report "$P_RUN" running
report "$P_WAIT" waiting
report "$P_ERR" error

OUT="$("$SCRIPT" --tick --frames 24 --dry-run 2>&1)"   # ~2.9s: one full breath and blink

# ------------------------------------------------------------------ reported state
run_seq=$(colors_for "$W_RUN" "$OUT")
wait_seq=$(colors_for "$W_WAIT" "$OUT")
err_seq=$(colors_for "$W_ERR" "$OUT")

is "running paints something" 1 "$([ -n "$run_seq" ] && echo 1 || echo 0)"
is "running breathes through several shades" \
   1 "$([ "$(printf '%s\n' "$run_seq" | sort -u | wc -l)" -ge 3 ] && echo 1 || echo 0)"
is "running shades are all green (g > r, g > b)" 1 "$(
  bad=0
  while read -r c; do
    h=${c#\#}
    r=$((0x${h:0:2})); g=$((0x${h:2:2})); b=$((0x${h:4:2}))
    { [ "$g" -gt "$r" ] && [ "$g" -gt "$b" ]; } || bad=1
  done <<< "$run_seq"
  [ "$bad" = 0 ] && echo 1 || echo 0)"

# Fluidity is measurable: many shades, and no visible jump between two frames.
is "a breath moves through at least ten shades" 1 "$(
   [ "$(printf '%s\n' "$run_seq" | sort -u | wc -l)" -ge 10 ] && echo 1 || echo 0)"
is "no single step in the breath is a visible jump" 1 "$(
  worst=0 prev=""
  while read -r c; do
    if [ -n "$prev" ]; then
      a=${prev#\#}; b=${c#\#}
      for o in 0 2 4; do
        d=$(( 0x${a:$o:2} - 0x${b:$o:2} )); [ "$d" -lt 0 ] && d=$(( -d ))
        [ "$d" -gt "$worst" ] && worst=$d
      done
    fi
    prev=$c
  done <<< "$run_seq"
  [ "$worst" -le 18 ] && echo 1 || echo 0)"   # a skipped ramp step would double this

is "unseen waiting flashes between two shades" \
   2 "$(printf '%s\n' "$wait_seq" | sort -u | wc -l | tr -d ' ')"
has "waiting flash uses the configured orange" "#d79921" "$wait_seq"
is "unseen error flashes between two shades" \
   2 "$(printf '%s\n' "$err_seq" | sort -u | wc -l | tr -d ' ')"
has "error flash uses the configured red" "#e06c75" "$err_seq"
is "dim end is the base scaled to 30%" "#2d3a24" "$(
  # #98c379 at 30%: 152,195,121 -> 45,58,36
  printf '#%02x%02x%02x' $((152 * 30 / 100)) $((195 * 30 / 100)) $((121 * 30 / 100)))"

# A window you are looking at is solid, not flashing. This needs a real client:
# `tmux attach` in a background shell has no terminal and never becomes one, so
# the session stays unattached and every window stays unwatched.
script -qfec "tmux attach-session -t $SESSION" /dev/null >/dev/null 2>&1 &
ATTACH=$!
sleep 1.5
tmux select-window -t "$SESSION:w-wait" 2>/dev/null
is "the fixture session has a client" \
   1 "$(tmux list-windows -t "$SESSION" -F '#{session_attached}' | head -1)"
OUT_SEEN="$("$SCRIPT" --tick --frames 16 --dry-run 2>&1)"
kill "$ATTACH" 2>/dev/null
seen_seq=$(colors_for "$W_WAIT" "$OUT_SEEN")
is "the window in front of you is solid" \
   1 "$([ "$(printf '%s\n' "$seen_seq" | sort -u | wc -l)" -le 1 ] && echo 1 || echo 0)"

# ------------------------------------------------------------------ precedence
# A screen cue must never override what the agent said about itself.
tmux send-keys -t "$SESSION:w-wait" '' 2>/dev/null
report "$P_WAIT" done
OUT2="$("$SCRIPT" --tick --frames 12 --dry-run 2>&1)"  # a full blink: this tab is unwatched
has "reported state wins over screen cues" "#98c379" "$(colors_for "$W_WAIT" "$OUT2")"

# ------------------------------------------------------------------ no agent
# Handing a window back to the theme is a transition, so it only happens inside
# a loop that saw the state and then saw it go.
"$SCRIPT" --tick --frames 24 --dry-run >"$CACHE/out3" 2>&1 &
PAINTER=$!
sleep 1
rm -f "$STATUS/$P_RUN" "$STATUS/$P_WAIT" "$STATUS/$P_ERR"
wait "$PAINTER" 2>/dev/null
OUT3="$(cat "$CACHE/out3")"
has "a pane that lost its agent is handed back to the theme" "$W_RUN -" "$OUT3"

# ------------------------------------------------------------------ crash
# An agent that said "running" and then vanished is an error. Only for a pane
# where the pattern positively matched first, which is what the second case
# checks: no match ever, so no verdict.
# `sh` first, `cat` after the exec: tmux reports the pane's own process, not its
# children, which is also why a tool-running agent still reads as the agent.
tmux new-window -t "$SESSION" -n w-crash 'sh -c "sleep 1; exec cat"'
sleep 0.3
W_CRASH=$(win w-crash); P_CRASH=$(pane w-crash)
report "$P_CRASH" running
OUT4="$(AGENT_STATUS_PATTERN='(^|/)(sh)( |$)' "$SCRIPT" --tick --frames 24 --dry-run 2>&1)"
crash_seq=$(colors_for "$W_CRASH" "$OUT4")
has "an agent that vanished mid-run turns red" "#e06c75" "$crash_seq"
is "the verdict is written down, not re-derived" error "$(cut -f1 "$STATUS/$P_CRASH")"

report "$P_CRASH" running
OUT5="$("$SCRIPT" --tick --frames 8 --dry-run 2>&1)"
hasnt "a process the pattern never matched is not called a crash" "#e06c75" "$(colors_for "$W_CRASH" "$OUT5")"

# ------------------------------------------------------------------ background
# Background work is in progress but the session is idle and will take input, so
# it gets its own colour and a slower breath rather than looking like running.
tmux new-window -t "$SESSION" -n w-bg 'sleep 600'
sleep 0.3
W_BG=$(win w-bg); P_BG=$(pane w-bg)
report "$P_BG" background
report "$P_RUN" running
OUT7="$("$SCRIPT" --tick --frames 24 --dry-run 2>&1)"
bg_seq=$(colors_for "$W_BG" "$OUT7")
run2_seq=$(colors_for "$W_RUN" "$OUT7")

is "background is a cyan, not a green" 1 "$(
  bad=0
  while read -r c; do
    h=${c#\#}
    r=$((0x${h:0:2})); g=$((0x${h:2:2})); b=$((0x${h:4:2}))
    { [ "$b" -gt "$r" ] && [ "$g" -gt "$r" ]; } || bad=1
  done <<< "$bg_seq"
  [ "$bad" = 0 ] && echo 1 || echo 0)"

is "background breathes, it does not blink" 1 "$(
  [ "$(printf '%s\n' "$bg_seq" | sort -u | wc -l)" -ge 5 ] && echo 1 || echo 0)"

swing() { # colour list -> brightest green channel minus dimmest
  local hi=0 lo=255 c h g
  while read -r c; do
    h=${c#\#}; g=$((0x${h:2:2}))
    [ "$g" -gt "$hi" ] && hi=$g
    [ "$g" -lt "$lo" ] && lo=$g
  done <<< "$1"
  echo $(( hi - lo ))
}
is "background breathes more slowly than running" 1 "$(
  [ "$(swing "$bg_seq")" -lt "$(swing "$run2_seq")" ] && echo 1 || echo 0)"

# a window where one pane works and another only has background work is working
tmux split-window -d -t "$SESSION:w-bg" 'sleep 600'
sleep 0.3
P_BG2=$(tmux list-panes -t "$SESSION:w-bg" -F '#{pane_id}' | tail -1)
report "$P_BG2" running
OUT8="$("$SCRIPT" --tick --frames 6 --dry-run 2>&1)"
is "running outranks background in the same window" 1 "$(
  bad=0
  while read -r c; do
    h=${c#\#}
    r=$((0x${h:0:2})); g=$((0x${h:2:2})); b=$((0x${h:4:2}))
    { [ "$g" -gt "$b" ] && [ "$g" -gt "$r" ]; } || bad=1
  done <<< "$(colors_for "$W_BG" "$OUT8")"
  [ "$bad" = 0 ] && echo 1 || echo 0)"
rm -f "$STATUS/$P_BG" "$STATUS/$P_BG2" "$STATUS/$P_RUN"

# ------------------------------------------------------------------ cues
# The regression that made this a rule: a session discussing a panic is not a
# panic. Fills the pane so the word is the bottom line - the place cues are read
# from - and expects no colour at all.
tmux new-window -t "$SESSION" -n w-prose \
  'sh -c "i=0; while [ \$i -lt 60 ]; do echo; i=\$((i+1)); done; echo \"panic: boom\"; exec cat"'
sleep 0.5
W_PROSE=$(win w-prose)
OUT6="$(AGENT_STATUS_PATTERN='(^|/)(cat)( |$)' "$SCRIPT" --tick --frames 6 --dry-run 2>&1)"
is "an error word on screen is not an error" "" "$(colors_for "$W_PROSE" "$OUT6")"

# ------------------------------------------------------------------ stale paint
# A killed painter leaves its last frame behind, so clearing has to reach every
# window, not only the ones this process painted.
tmux set -w -t "$W_RUN" @agent-tab-color '#ff0000'
"$SCRIPT" clear-all
# show-options -w reports the window's own value, so "empty" means the window
# stopped overriding and inherits the theme again - display-message would show
# the inherited global and pass either way.
is "clear-all takes back a colour this process never set" \
   "" "$(tmux show-options -w -t "$W_RUN" @agent-tab-color 2>/dev/null)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]

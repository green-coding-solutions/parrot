#!/usr/bin/env bash
# Helpers for measuring landmarks by hand against a running window-container.
#
#   source measure.sh
#   start_app 'element-desktop'    # launch and wait for the window
#   K ctrl+k; sleep 2; SHOT filter-open
#   WINS                           # list every window with geometry
#   TRUTH sent --room windvane-deployment
#
# Screenshots land in the scratchpad on the host so they can be looked at.
SHOTDIR="${SHOTDIR:-/tmp/claude-1000/-home-didi-code-parrot/c8b796e2-4655-470f-bc78-d354c5f0e4be/scratchpad/shots}"
mkdir -p "$SHOTDIR"

X() { docker exec -e DISPLAY=:99 window-container xdotool "$@" >/dev/null 2>&1; }
Q() { docker exec -e DISPLAY=:99 window-container bash -c "$1" 2>/dev/null; }
K() { X key --clearmodifiers "$1"; }
T() { X type --delay 45 -- "$1"; }

# Every window xdotool can see, with geometry - the thing to check after any
# action that might have opened a dialog, and the way to read a client's
# res_name for pin-windows.sh.
WINS() {
  Q 'for w in $(xdotool search --onlyvisible --class . 2>/dev/null); do
       n=$(xdotool getwindowname $w 2>/dev/null)
       g=$(xdotool getwindowgeometry --shell $w 2>/dev/null | grep -E "^(X|Y|WIDTH|HEIGHT)=" | tr "\n" " ")
       c=$(xprop -id $w WM_CLASS 2>/dev/null | sed "s/.*= //")
       echo "  [$n] $g CLASS=$c"
     done'
}

# Capture the whole root, not one window: a dialog stacked over the timeline is
# only visible in a root capture, and an obscured window captured with
# `import -window` comes back with unpainted area as solid black.
SHOT() {
  local name="${1:?SHOT <name>}"
  docker exec -e DISPLAY=:99 window-container import -window root "/tmp/${name}.png" 2>/dev/null
  docker cp "window-container:/tmp/${name}.png" "${SHOTDIR}/${name}.png" >/dev/null
  echo "  -> ${SHOTDIR}/${name}.png"
}

# Launch a client. The Flatpak entrants go through flatpak-session, which drops
# to uid 1001 - pass the whole command including that wrapper.
start_app() {
  local cmd="${1:?start_app <command>}" wait="${2:-40}"
  docker exec -d -e DISPLAY=:99 window-container bash -c "$cmd >/tmp/app.log 2>&1"
  sleep "$wait"
  WINS
}

APPLOG() { docker exec window-container tail -n "${1:-40}" /tmp/app.log 2>/dev/null; }

# Ground truth. Runs INSIDE the matrix container, where the corpus manifest is,
# so room keys like `windvane-deployment` resolve without guessing room ids.
#
# Use it after every mutating block, not at the end. AGENTS.md: verify against
# ground truth, not against the screenshots - a chat client that renders a
# message optimistically shows exactly the same pixels whether or not the
# server ever accepted it.
TRUTH() {
  docker exec matrix-container python3 \
    /tmp/repo/applications/chatclients/common/matrix-truth.py \
    --homeserver http://127.0.0.1:8008 "$@"
}

#!/usr/bin/env bash
# Helpers for measuring landmarks by hand against a running window-container.
#
#   source measure.sh
#   start_app 'soffice --writer'   # launch and wait for the window
#   K ctrl+o; sleep 2; SHOT open-dialog
#   WINS                           # list every window with geometry
#
# Screenshots land in the scratchpad on the host so they can be looked at.
SHOTDIR="${SHOTDIR:-/tmp/claude-1000/-home-didi-code-parrot/176567fa-cbfc-4bb8-b469-20aec1066d73/scratchpad/shots}"
mkdir -p "$SHOTDIR"

X() { docker exec -e DISPLAY=:99 window-container xdotool "$@" >/dev/null 2>&1; }
Q() { docker exec -e DISPLAY=:99 window-container bash -c "$1" 2>/dev/null; }
K() { X key --clearmodifiers "$1"; }
T() { X type --delay 45 -- "$1"; }

# Every window xdotool can see, with geometry - the thing to check after any
# action that might have opened a dialog.
WINS() {
  Q 'for w in $(xdotool search --onlyvisible --class . 2>/dev/null); do
       n=$(xdotool getwindowname $w 2>/dev/null)
       g=$(xdotool getwindowgeometry --shell $w 2>/dev/null | grep -E "^(X|Y|WIDTH|HEIGHT)=" | tr "\n" " ")
       echo "  [$n] $g"
     done'
}

# Capture the whole root, not one window: a dialog stacked over the document is
# only visible in a root capture, and an obscured window captured with
# `import -window` comes back with unpainted area as solid black.
SHOT() {
  local name="${1:?SHOT <name>}"
  docker exec -e DISPLAY=:99 window-container import -window root "/tmp/${name}.png" 2>/dev/null
  docker cp "window-container:/tmp/${name}.png" "${SHOTDIR}/${name}.png" >/dev/null
  echo "  -> ${SHOTDIR}/${name}.png"
}

start_app() {
  local cmd="${1:?start_app <command>}" wait="${2:-50}"
  docker exec window-container bash -c 'pkill -f soffice >/dev/null 2>&1; true'
  sleep 3
  docker exec -d -e DISPLAY=:99 window-container bash -c "$cmd >/tmp/app.log 2>&1"
  sleep "$wait"
  WINS
}

# The status bar is the cheapest ground truth Writer offers: page N of M, the
# word count, and whether the document is modified. Read it off the screenshot
# rather than trusting that a keystroke did what it looked like it did.
STATUS() {
  docker exec -e DISPLAY=:99 window-container bash -c \
    'import -window root -crop 1440x22+0+878 +repage /tmp/status.png 2>/dev/null'
  docker cp window-container:/tmp/status.png "${SHOTDIR}/status.png" >/dev/null
  echo "  -> ${SHOTDIR}/status.png"
}

#!/usr/bin/env bash
# Helpers for measuring landmarks by hand against a running window-container.
#
#   source measure.sh
#   start_app parrot-xterm         # launch and wait for the window
#   T 'corpus/plain.sh'; K Return; sleep 3; SHOT after-plain
#   WINS                           # list every window with geometry
#   GEOM                           # the terminal's own size, which is NOT 1440x900
#   STEADY                         # is the screen byte-identical to itself?
#
# Screenshots land in the scratchpad on the host so they can be looked at.
SHOTDIR="${SHOTDIR:-/tmp/claude-1000/-home-didi-code-parrot/e0961f5a-c6da-4f82-963c-c6f942b35be8/scratchpad/shots}"
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

# Terminals start in well under a second - nothing here is a 50-second office
# suite - but gnome-terminal forks to a server and konsole talks to dbus, so the
# default still waits several seconds rather than assuming.
#
# The kill uses `pkill -x` on purpose. `pkill -f kitty` matched the `bash -c`
# command line that CONTAINED the word kitty and killed the measuring shell
# itself; -x matches the process name exactly and cannot do that.
start_app() {
  local cmd="${1:?start_app <command>}" wait="${2:-6}"
  for p in xterm urxvt gnome-terminal-server konsole alacritty kitty st; do
      docker exec window-container bash -c "pkill -x $p >/dev/null 2>&1; true"
  done
  sleep 2
  docker exec -d -e DISPLAY=:99 window-container bash -c "$cmd >/tmp/app.log 2>&1"
  sleep "$wait"
  WINS
}

# The terminal's own geometry, which is NOT the geometry that was asked for.
# Every entrant sizes itself to whole character cells and then adds its border,
# so a pin to 1440x900 comes back as something near it and different per app -
# xterm lands on 1435x897. The number this prints is what that app's driver has
# to assert, and what belongs in its MEASUREMENTS.md.
GEOM() {
  Q 'w=$(xdotool getactivewindow 2>/dev/null); \
     xdotool getwindowgeometry --shell $w | grep -E "^(WIDTH|HEIGHT)=" | tr "\n" " "; \
     echo; xprop -id $w WM_CLASS'
}

# The check to run before anything else on a new entrant, and the reason kitty
# needed a config change: an idle window that is not byte-identical to itself
# 1.5s later cannot be replay-verified, because every checkpoint after the first
# photographs a different screen than the reference. The usual cause is a
# blinking cursor; the other is an animated theme.
STEADY() {
  Q 'w=$(xdotool getactivewindow 2>/dev/null)
     import -window $w /tmp/s1.png 2>/dev/null; sleep 1.5
     import -window $w /tmp/s2.png 2>/dev/null
     cmp -s /tmp/s1.png /tmp/s2.png && echo "  STEADY" || echo "  CHANGES - cannot be replay-verified"'
}

# What the emulator advertises itself as, and what the shell inside actually
# sees. Recorded per app rather than normalised: TERM is a real property of the
# emulator and forcing it identical everywhere would hide a genuine difference.
TERMVAR() { Q 'xdotool type --clearmodifiers "echo TERM=\$TERM"'; K Return; }

# The session log the ground truth is built on, as it stands right now. Useful
# mid-measurement to see which blocks have actually logged themselves.
TLOG() { Q 'cat /tmp/parrot-term.log 2>/dev/null || echo "  (no log yet)"'; }

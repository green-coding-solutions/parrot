#!/usr/bin/env bash
# Measure one emulator's window, and print the driver.conf lines it implies.
#
#   common/measure-window.sh <app>
#
# Left alone a terminal CANNOT be pinned to an exact pixel size: it sizes itself
# to whole character cells and then adds its border, so a pin to 1440x900 comes
# back as something near it and different per app - xterm and st both land on
# 1435x897.
#
# Under the harness it is 1440x900 anyway, because record-macro.py resizes the
# window to the display size before recording and replay.py resizes it to the
# reference image's size on replay. So this script is not what decides the
# driver's assertion; it is here to report an app's NATURAL size and, more
# usefully, its grid, TERM, colour depth and whether its screen is steady.
#
# The grid is the number that matters: it decides how the corpus wraps, and an
# entrant with a different cell size gets a different number of columns.
#
# This rebuilds the container, so it is safe to run against a machine that has
# been used for something else.
set -euo pipefail

REPO=/home/didi/code/parrot
APP="${1:?usage: measure-window.sh <app>}"
cd "$REPO"

CONF="applications/terminals/${APP}/driver.conf"
[[ -f "$CONF" ]] || { echo "no driver.conf for ${APP}" >&2; exit 1; }
# shellcheck source=/dev/null
source "$CONF"
LOAD_WAIT="${LOAD_WAIT:-8}"

echo "=== rebuilding the container for ${APP} ==="
bash applications/terminals/common/setup-container.sh "$APP" --measure >/dev/null
docker exec window-container bash -c 'rm -f /tmp/parrot-term.log'

echo "=== launching /usr/local/bin/parrot-${APP} ==="
docker exec -d -e DISPLAY=:99 window-container \
    bash -c "/usr/local/bin/parrot-${APP} >/tmp/app.log 2>&1"
sleep "$LOAD_WAIT"

Q() { docker exec -e DISPLAY=:99 window-container bash -c "$1" 2>/dev/null; }

win="$(Q 'xdotool getactivewindow 2>/dev/null')"
if [[ -z "$win" ]]; then
    echo "  NO WINDOW after ${LOAD_WAIT}s - app log:"
    docker exec window-container cat /tmp/app.log 2>/dev/null | sed 's/^/    /' | head -20
    exit 1
fi

geo="$(Q "xdotool getwindowgeometry --shell ${win} | grep -E '^(WIDTH|HEIGHT)='")"
W="$(sed -n 's/^WIDTH=//p'  <<<"$geo")"
H="$(sed -n 's/^HEIGHT=//p' <<<"$geo")"

echo "  WM_CLASS : $(Q "xprop -id ${win} WM_CLASS" | sed 's/^.*= //')"
echo "  geometry : ${W}x${H}   (asked for 1440x900)"

# The grid, TERM and colour depth read from inside the shell rather than
# inferred: type it, let the shell answer into a file, read the file. Reading it
# off a screenshot would mean trusting OCR for a number the driver depends on.
Q "xdotool windowactivate --sync ${win}; sleep 0.5
   xdotool type --delay 30 -- 'stty size > /tmp/g.txt; echo TERM=\$TERM >> /tmp/g.txt; tput colors >> /tmp/g.txt; echo LANG=\$LANG >> /tmp/g.txt'
   xdotool key Return" >/dev/null
sleep 3
inside="$(docker exec window-container cat /tmp/g.txt 2>/dev/null)"
rows="$(awk 'NR==1{print $1}' <<<"$inside")"
cols="$(awk 'NR==1{print $2}' <<<"$inside")"
echo "  grid     : ${cols} columns x ${rows} rows"
echo "  $(sed -n '2p' <<<"$inside")"
echo "  colours  : $(sed -n '3p' <<<"$inside")"
echo "  $(sed -n '4p' <<<"$inside")"
if [[ -n "${cols:-}" && -n "${rows:-}" && "$cols" -gt 0 && "$rows" -gt 0 ]]; then
    echo "  cell     : $((W / cols))x$((H / rows)) px approx (border included)"
fi

# The steady-screen test. An idle window that is not byte-identical to itself
# cannot be replay-verified at all - every checkpoint after the first
# photographs a different screen than the reference. It is what ruled out
# kitty's default configuration and cool-retro-term entirely.
echo -n "  steady   :"
Q 'w=$(xdotool getactivewindow)
   import -window $w /tmp/s1.png 2>/dev/null; sleep 1.5
   import -window $w /tmp/s2.png 2>/dev/null
   cmp -s /tmp/s1.png /tmp/s2.png && echo " yes" || echo " NO - blinking cursor or animation; cannot be recorded"'

echo
echo "driver.conf for ${APP}:"
echo "  WANT_W=${W}"
echo "  WANT_H=${H}"

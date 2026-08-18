#!/usr/bin/env bash
# Find which key actually scrolls an emulator's scrollback.
#
#   common/probe-scrollkeys.sh <app>
#
# WHY THIS EXISTS. The first capability probe for this group reported that all
# seven entrants scrolled with Shift+Page Up. That was wrong, and the way it was
# wrong is worth knowing: in st, Shift+Page Up is not a binding at all - the key
# is passed through to the application as `ESC[5;2~`, readline swallows the
# `ESC[` and leaves `2~` sitting on the command line. Twenty presses left
# `2~2~2~...` on the prompt, the next block's command was appended to that junk,
# and it never ran. The recording still produced a full set of checkpoints and
# reference screenshots; only the session log showed anything was wrong.
#
# The outcome: there is no scrollback gesture the seven share, so those two
# blocks were dropped from script.md. This is kept because it is the right way
# to test the question for any new entrant.
#
# HOW IT AVOIDS THE SAME MISTAKE. Two rules:
#
#   1. Hash only the TOP of the window, never the whole thing. A key that types
#      junk onto the prompt line changes the full-window hash exactly like a key
#      that scrolls, which is what made the original probe report a false pass.
#      The prompt is at the bottom; the content is at the top.
#   2. Relaunch the emulator between candidates. Without a reset, every hash
#      after the first successful scroll differs from the baseline, so every
#      later candidate looks like it worked too.
set -euo pipefail

REPO=/home/didi/code/parrot
APP="${1:?usage: probe-scrollkeys.sh <app>}"
cd "$REPO"

# shellcheck source=/dev/null
source "applications/terminals/${APP}/driver.conf"
LOAD_WAIT="${LOAD_WAIT:-8}"

Q() { docker exec -e DISPLAY=:99 window-container bash -c "$1" 2>/dev/null; }
HT() { Q 'w=$(xdotool getactivewindow); import -window $w -crop 1400x700+0+0 +repage png:- 2>/dev/null | md5sum | cut -c1-10'; }

relaunch() {
    Q "pkill -x ${1} >/dev/null 2>&1; true" || true
    sleep 1.5
    docker exec -d -e DISPLAY=:99 window-container \
        bash -c "/usr/local/bin/parrot-${APP} >/dev/null 2>&1"
    sleep "$LOAD_WAIT"
    Q 'w=$(xdotool getactivewindow); xdotool windowactivate --sync $w
       xdotool type --delay 20 "corpus/plain.sh"; xdotool key Return' >/dev/null
    sleep 7
}

echo "=== ${APP}: which key scrolls the scrollback? ==="
# The process name to kill is not always the app name - gnome-terminal's window
# belongs to gnome-terminal-server, and st's binary is `st` while its class is
# st-256color.
case "$APP" in
    gnome-terminal) PROC=gnome-terminal-server ;;
    st)             PROC=st ;;
    urxvt)          PROC=urxvt ;;
    *)              PROC="$APP" ;;
esac

for k in shift+Prior ctrl+shift+Prior alt+Prior shift+Up; do
    relaunch "$PROC"
    base="$(HT)"
    Q "xdotool key --clearmodifiers ${k}" >/dev/null
    sleep 1.5
    after="$(HT)"
    if [[ "$base" == "$after" ]]; then
        printf '  %-20s no scroll\n' "$k"
    else
        # It moved. Now check the matching DOWN key brings it back: a scroll
        # that cannot be undone leaves the next block starting from an unknown
        # screen, which is what ruled Konsole out.
        down="${k/Prior/Next}"; down="${down/Up/Down}"
        Q "xdotool key --clearmodifiers ${down}" >/dev/null
        sleep 1.5
        back="$(HT)"
        if [[ "$back" == "$base" ]]; then
            printf '  %-20s SCROLLS, and %s returns exactly\n' "$k" "$down"
        else
            printf '  %-20s scrolls, but %s does NOT return to the start\n' "$k" "$down"
        fi
    fi
done

# Junk on the command line is the other half of the answer: a key that is passed
# through to the application rather than consumed by the emulator corrupts the
# next command even when it does no visible harm itself.
echo "  --- does any candidate leave junk on the prompt? ---"
relaunch "$PROC"
for k in shift+Prior ctrl+shift+Prior; do
    Q "for i in 1 2 3; do xdotool key --clearmodifiers ${k}; sleep 0.4; done" >/dev/null
    sleep 1
    line="$(Q 'w=$(xdotool getactivewindow); import -window $w -crop 700x22+0+878 +repage png:- 2>/dev/null | md5sum | cut -c1-8')"
    Q 'xdotool type --delay 10 " "; xdotool key --clearmodifiers ctrl+u' >/dev/null
    printf '  %-20s prompt-line hash %s\n' "$k" "$line"
done
echo "  (compare against a clean prompt by eye with a crop if these differ)"

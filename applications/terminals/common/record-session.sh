#!/usr/bin/env bash
# Record one emulator's .parrot end to end.
#
#   common/record-session.sh <app>
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. That matters more here than in the other groups, because
# the session log at /tmp/parrot-term.log is the whole of the ground truth and it
# is APPENDED to. A recording made against a container that has already been
# driven once starts with ten BLOCK lines already in the log, so verify.sh counts
# twenty and reports a failure - or worse, passes on the PREVIOUS run's evidence
# while this run did nothing at all.
set -euo pipefail

REPO=/home/didi/code/parrot
APP="${1:?usage: record-session.sh <app>}"
cd "$REPO"

CONF="applications/terminals/${APP}/driver.conf"
[[ -f "$CONF" ]] || { echo "no driver.conf for ${APP}" >&2; exit 1; }
# shellcheck source=/dev/null
source "$CONF"
: "${CLASS:?driver.conf must set CLASS}"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/terminals/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# --startcommand is the generated launcher, never the bare binary. The launcher
# sources /etc/parrot-env for the UTF-8 locale and does whatever else the app
# needs first - xrdb for xterm and urxvt, dbus-run-session for GNOME Terminal.
# A bare binary here comes up in the C locale and draws the Unicode and line-art
# blocks as Latin-1 mojibake.
#
# --windowclass is the res_class from driver.conf (xdotool's class match is
# case-insensitive). Every entrant opens exactly one window and no dialogs, so
# record-macro.py's first match and replay.py's largest match are the same
# window - unlike the office suites, where they were not. The driver's CP()
# asserts the size anyway.
./record-macro.py \
    --script applications/terminals/script.md \
    --startcommand "/usr/local/bin/parrot-${APP}" \
    --windowclass "$CLASS" \
    "applications/terminals/${APP}/${APP}.parrot" &
RECORDER=$!

# The recorder launches the app and arms xmacrorec2; give both time to come up
# before any event is sent, or the first block is recorded without its opening
# keystrokes.
sleep 12

bash "applications/terminals/common/drive-scenario.sh" "$APP"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/terminals/${APP}/${APP}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/terminals/${APP}/${APP}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

echo "=== ground truth ==="
# Judge the recording by this, not by how the screens looked. A terminal writes
# no document and its output scrolls away, so a plausible-looking set of
# reference images is no evidence at all that the blocks ran.
docker exec -e DISPLAY=:99 window-container /opt/parrot/corpus/verify.sh 2>&1 | sed 's/^/  /'

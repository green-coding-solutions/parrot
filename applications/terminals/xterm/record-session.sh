#!/usr/bin/env bash
# Record applications/terminals/xterm/xterm.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. That matters more here than in the other groups: the
# session log at /tmp/parrot-term.log is the whole of the ground truth, and it is
# APPENDED to. A recording made against a container that has already been driven
# once starts with ten BLOCK lines already in the log, so verify.sh would count
# twenty and report a failure - or worse, would pass on the previous run's
# evidence while this run did nothing.
set -euo pipefail

REPO=/home/didi/code/parrot
APP=xterm
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/terminals/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# --windowclass xterm matches the res_class `XTerm` (xdotool's class match is
# case-insensitive). xterm opens exactly one window and no dialogs, so the first
# match and the largest match are the same window - unlike the office suites,
# where they were not. drive-scenario.sh's CP() asserts the size anyway.
#
# --startcommand is the generated launcher, not `xterm`. The launcher sources
# /etc/parrot-env for the UTF-8 locale and loads the X resources with xrdb; bare
# `xterm` would come up in the C locale with default resources and draw the
# Unicode and line-art blocks as Latin-1 mojibake.
./record-macro.py \
    --script applications/terminals/script.md \
    --startcommand '/usr/local/bin/parrot-xterm' \
    --windowclass xterm \
    "applications/terminals/${APP}/${APP}.parrot" &
RECORDER=$!

# The recorder launches the app and arms xmacrorec2; give both time to come up
# before any event is sent, or the first block is recorded without its opening
# keystrokes.
sleep 12

bash "applications/terminals/${APP}/drive-scenario.sh"

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

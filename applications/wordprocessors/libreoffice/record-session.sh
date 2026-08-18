#!/usr/bin/env bash
# Record applications/wordprocessors/libreoffice/libreoffice.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. A recording made against a container that has already
# been driven once is a recording of the second run: the document still carries
# the edits, the PDF is already on disk, and the reference images show a state
# the first replay will never be in.
set -euo pipefail

REPO=/home/didi/code/parrot
APP=libreoffice
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/wordprocessors/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# windowclass libreoffice matches the document window and every dialog alike
# (xdotool's class match is case-insensitive), but replay.py takes the LARGEST
# match, which is always the 1440x900 document. record-macro.py takes the first
# match instead - which is why drive-scenario.sh's CP() asserts the size.
./record-macro.py \
    --script applications/wordprocessors/script.md \
    --startcommand 'soffice --writer' \
    --windowtitle 'LibreOffice Writer' \
    --windowclass libreoffice \
    "applications/wordprocessors/${APP}/${APP}.parrot" &
RECORDER=$!

# The recorder launches the app and arms xmacrorec2; give both time to come up
# before any event is sent, or the first block is recorded without its opening
# keystrokes.
sleep 12

bash "applications/wordprocessors/${APP}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/wordprocessors/${APP}/${APP}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/wordprocessors/${APP}/${APP}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

echo "=== ground truth ==="
bash applications/wordprocessors/common/check-result.sh

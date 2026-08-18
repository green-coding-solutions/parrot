#!/usr/bin/env bash
# Record applications/wordprocessors/openoffice/openoffice.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. A recording made against a container that has already
# been driven once is a recording of the second run: the document still carries
# the edits, the PDF is already on disk, and the reference images show a state
# the first replay will never be in.
#
# It matters more here than for LibreOffice. AOO keeps a RecoveryList in its
# profile for every open document, so a second start in the same container opens
# "OpenOffice Document Recovery" instead of the document - and no profile key
# turns that off. A fresh container is the only clean start.
set -euo pipefail

REPO=/home/didi/code/parrot
APP=openoffice
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/wordprocessors/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# windowclass openoffice matches on the res_class "OpenOffice 4.1.16", which the
# document window, every dialog, the message boxes and the floating context
# toolbars all share (xdotool's class match is a case-insensitive substring).
# replay.py takes the LARGEST match, which is always the 1440x900 document. The
# checkpoint capture in timed_xmacro.py takes `head -n1` instead - the first
# match - which is why drive-scenario.sh's CP() asserts both the size and the
# title.
./record-macro.py \
    --script applications/wordprocessors/script.md \
    --startcommand 'soffice -writer' \
    --windowtitle 'OpenOffice Writer' \
    --windowclass openoffice \
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
PDF_PAGES=100
[[ -f "applications/wordprocessors/${APP}/expected-pdf-pages" ]] &&
    PDF_PAGES="$(tr -dc '0-9' < "applications/wordprocessors/${APP}/expected-pdf-pages")"
bash applications/wordprocessors/common/check-result.sh window-container "$PDF_PAGES"

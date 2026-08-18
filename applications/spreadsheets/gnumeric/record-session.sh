#!/usr/bin/env bash
# Record applications/spreadsheets/gnumeric/gnumeric.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. A recording made against a container that has already
# been driven once is a recording of the second run: the workbook still carries
# the sort, the formulas and the replaced anchors, the PDF is already on disk,
# and the reference images show a state the first replay will never be in.
set -euo pipefail

REPO=/home/didi/code/parrot
APP=gnumeric
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/spreadsheets/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# windowclass gnumeric matches the document window, every dialog, and the filter
# dropdown alike (xdotool's class match is case-insensitive). replay.py takes the
# LARGEST match, which is always the 1440x900 document; record-macro.py takes the
# FIRST - which is why drive-scenario.sh's CP() asserts the size before every
# capture. Gnumeric's filter popup is 82x209 and sorts ahead of the document.
./record-macro.py \
    --script applications/spreadsheets/script.md \
    --startcommand 'gnumeric' \
    --windowtitle 'Gnumeric' \
    --windowclass gnumeric \
    "applications/spreadsheets/${APP}/${APP}.parrot" &
RECORDER=$!

# The recorder launches the app and arms xmacrorec2; give both time to come up
# before any event is sent, or the first block is recorded without its opening
# keystrokes.
sleep 12

bash "applications/spreadsheets/${APP}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/spreadsheets/${APP}/${APP}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/spreadsheets/${APP}/${APP}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

echo "=== ground truth ==="
# The expected PDF page count is per-app - the applications paginate the same
# print ranges differently (LibreOffice 9, Gnumeric 11) - so it is read from
# beside the scenario the way verify-app.sh reads it. Without this the check
# runs against the default and reports a FAIL that is only a missing argument.
PDF_PAGES=9
[[ -f "applications/spreadsheets/${APP}/expected-pdf-pages" ]] &&
    PDF_PAGES="$(tr -dc '0-9' < "applications/spreadsheets/${APP}/expected-pdf-pages")"
bash applications/spreadsheets/common/check-result.sh window-container "$PDF_PAGES"

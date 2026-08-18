#!/usr/bin/env bash
# Record applications/wordprocessors/abiword/abiword.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. A recording made against a container that has already
# been driven once is a recording of the second run: the document still carries
# the edits, the PDF is already on disk, and the reference images show a state
# the first replay will never be in.
set -euo pipefail

REPO=/home/didi/code/parrot
APP=abiword
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/wordprocessors/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# --windowclass is DELIBERATELY EMPTY, and that emptiness has to survive into
# the .parrot file - helpers.normalize_app_meta preserves an explicitly supplied
# empty value for exactly this reason.
#
# AbiWord never destroys its Find, Replace and message-box windows. They stay
# IsViewable at 0,0 after being closed and they sort AHEAD of the document in
# `xdotool search --onlyvisible --class abiword`, so the checkpoint capture -
# which takes head -n1 - would photograph a dead 478x254 dialog from block 8
# onwards. Matching on the title instead picks the document every time.
#
# The regex is anchored because an unanchored "Parrot Field Report" also matches
# "Replace - *Parrot Field Report", and it covers all three titles the document
# window has: Untitled1 before the open, then with and without the modified `*`.
# AbiWord titles the window from the document's dc:title, not its filename.
./record-macro.py \
    --script applications/wordprocessors/script.md \
    --startcommand 'abiword' \
    --windowtitle '^(Untitled1|[*]?Parrot Field Report)$' \
    --windowclass '' \
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
# The empty windowclass is load-bearing. If it ever comes back as
# "gnome-calculator" the default has crept in and replay will match nothing.
grep -E '^windowclass|^windowtitle' "applications/wordprocessors/${APP}/${APP}.parrot" \
    | sed 's/^/  /'

echo "=== ground truth ==="
PDF_PAGES=100
[[ -f "applications/wordprocessors/${APP}/expected-pdf-pages" ]] &&
    PDF_PAGES="$(tr -dc '0-9' < "applications/wordprocessors/${APP}/expected-pdf-pages")"
bash applications/wordprocessors/common/check-result.sh window-container "$PDF_PAGES"

#!/usr/bin/env bash
# Record applications/wordprocessors/freeoffice/freeoffice.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. A recording made against a container that has already
# been driven once is a recording of the second run: the document still carries
# the edits, the PDF is already on disk, and the reference images show a state
# the first replay will never be in.
set -euo pipefail

REPO=/home/didi/code/parrot
APP=freeoffice
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/wordprocessors/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# --windowclass is DELIBERATELY EMPTY, and that emptiness has to survive into
# the .parrot file - helpers.normalize_app_meta preserves an explicitly supplied
# empty value for exactly this reason.
#
# Every TextMaker dialog reports WM_CLASS "tm", "tm" as well as the document
# window does, and the checkpoint capture takes head -n1 of the class search.
# The dialogs here are better behaved than AbiWord's - they keep their natural
# size and are destroyed on close - but there is no reason to depend on that.
#
# The regex covers all three titles the document window carries: `Untitled 1 -
# TextMaker` before the open, then with and without the modified `*`. The `*`
# appears at the first Search in block 7, before anything has been edited.
#
# TextMaker opens one top-level window per document, so a second open document
# would be a second match. Block 2 does not create one - the empty Untitled 1 is
# reused - and drive-scenario.sh's CP() asserts the match count anyway.
./record-macro.py \
    --script applications/wordprocessors/script.md \
    --startcommand 'textmaker24free' \
    --windowtitle '^.+ - TextMaker$' \
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

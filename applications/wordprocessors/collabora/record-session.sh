#!/usr/bin/env bash
# Record applications/wordprocessors/collabora/collabora.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. A recording made against a container that has already
# been driven once is a recording of the second run: the document still carries
# the edits, the PDF is already on disk, and the reference images show a state
# the first replay will never be in.
#
# Rebuilding here is expensive - about 850 MB of Flatpak comes down - so budget
# a few minutes before anything appears to happen.
set -euo pipefail

REPO=/home/didi/code/parrot
APP=collabora
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/wordprocessors/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# Matched on CLASS. WM_CLASS is "coda-qt", "Collabora Office" - this is
# Collabora Online's Chromium UI running offline, not LibreOffice's soffice, and
# the first guess of `soffice` pinned nothing at all while reporting success.
#
# `collabora`, not `coda-qt`: xdotool's --class matches the res_CLASS half of
# WM_CLASS while fluxbox's pin rule matches the res_NAME half, and this is the
# one application in the group where the two are different strings. See
# drive-scenario.sh.
#
# Exactly one such window exists at every checkpoint: the start screen closes
# itself when the document window appears, and both file dialogs are shut before
# their block ends. drive-scenario.sh's CP() asserts that, because record-macro.py
# captures head -n1 of the class search rather than the largest match.
#
# The launch goes through flatpak-session, which supplies the system bus, the
# session bus and the XDG_RUNTIME_DIR that `flatpak run` needs and this image has
# none of - without it flatpak stops at "Could not connect: No such file or
# directory", which reads like a missing file rather than a missing bus.
./record-macro.py \
    --script applications/wordprocessors/script.md \
    --startcommand 'flatpak-session flatpak run com.collaboraoffice.Office' \
    --windowclass collabora \
    "applications/wordprocessors/${APP}/${APP}.parrot" &
RECORDER=$!

# The recorder arms xmacrorec2 and gives the app one second to show a window,
# which this one has no chance of meeting - a Flatpak sandbox and a Chromium
# have to start first, about 55 s cold. drive-scenario.sh's block 1 waits it out;
# this sleep only has to cover the recorder's own setup.
sleep 12

bash "applications/wordprocessors/${APP}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/wordprocessors/${APP}/${APP}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/wordprocessors/${APP}/${APP}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

echo "=== ground truth ==="
# No expected-pdf-pages file: Collabora paginates this document to 98 like
# LibreOffice and OpenOffice, so the run's 100 is the group default.
bash applications/wordprocessors/common/check-result.sh

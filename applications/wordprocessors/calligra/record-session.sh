#!/usr/bin/env bash
# Record applications/wordprocessors/calligra/calligra.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first. A recording made against a container that has already
# been driven once is a recording of the second run: the document still carries
# the edits, the PDF is already on disk, and the reference images show a state
# the first replay will never be in.
#
# Rebuilding pulls a Flatpak runtime, so budget a few minutes before anything
# appears to happen.
set -euo pipefail

REPO=/home/didi/code/parrot
APP=calligra
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "applications/wordprocessors/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# Matched on CLASS. WM_CLASS is "calligrawords", "calligrawords" - both halves
# the same, so one string serves both the fluxbox pin rule and xdotool. That is
# NOT true of Collabora, where they differ; confirmed here against a live window
# rather than assumed.
#
# Menus and combo popups are separate X windows carrying this same class and
# sorting ahead of the document, and the Insert Table dialog is pinned to
# 1440x900 like the document itself - so drive-scenario.sh's CP() asserts the
# match COUNT as well as the geometry.
#
# --command=calligrawords is required: the Flatpak's default command is
# calligralauncher, the suite chooser, not Words.
./record-macro.py \
    --script applications/wordprocessors/script.md \
    --startcommand 'flatpak-session flatpak run --command=calligrawords org.kde.calligra' \
    --windowclass calligrawords \
    "applications/wordprocessors/${APP}/${APP}.parrot" &
RECORDER=$!

# The recorder arms xmacrorec2 and gives the app one second to show a window,
# which a Flatpak has no chance of meeting. drive-scenario.sh's block 1 waits it
# out; this sleep only covers the recorder's own setup.
sleep 12

bash "applications/wordprocessors/${APP}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/wordprocessors/${APP}/${APP}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/wordprocessors/${APP}/${APP}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

echo "=== ground truth ==="
# 122 pages, not the group default of 100: Calligra paginates the document to
# 120 rather than 98 because its ODF import does not apply the document's fonts,
# and the run adds one page for the table and one for the page break. The
# inserted image is a floating shape here and adds no page.
bash applications/wordprocessors/common/check-result.sh window-container \
    "$(tr -dc '0-9' < "applications/wordprocessors/${APP}/expected-pdf-pages")"

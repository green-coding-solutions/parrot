#!/usr/bin/env bash
# Record applications/codeeditors/vscode/vscode.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first, because a recording made against a container that has
# already been driven once is a recording of the second run: the workspace still
# has the edits, VS Code still has the file open, and the reference images show
# a state the first replay will never be in.
set -euo pipefail

REPO=/home/didi/code/parrot
EDITOR_NAME=vscode
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash applications/codeeditors/common/verify-editor.sh "$EDITOR_NAME" --setup

echo "=== starting the recorder ==="
# --windowclass code matches the editor and its dialogs alike (xdotool's class
# match is case-insensitive), but replay.py and check-image.sh both take the
# LARGEST match, which is always the 1440x900 editor.  record-macro.py takes the
# first match instead - drive-scenario.sh's CP() asserts the size for that
# reason.
./record-macro.py \
    --script applications/codeeditors/script.md \
    --startcommand 'vscode /root/project' \
    --windowtitle 'Visual Studio Code' \
    --windowclass code \
    "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" &
RECORDER=$!

# The recorder launches the app and arms xmacrorec2; give both time to come up
# before any event is sent, or the first block is recorded without its opening
# keystrokes.
sleep 12

bash "applications/codeeditors/${EDITOR_NAME}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

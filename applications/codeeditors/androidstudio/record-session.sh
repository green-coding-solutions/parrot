#!/usr/bin/env bash
# Record applications/codeeditors/androidstudio/androidstudio.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first.  Android Studio's first block is the usage-statistics
# consent and the project-trust prompt, and neither appears against a profile
# that has been used once - so recording against a container that has already
# been driven would produce a first block with no dialogs in it and a replay
# that clicks at empty screen.
set -euo pipefail

REPO=/home/didi/code/parrot
EDITOR_NAME=androidstudio
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash applications/codeeditors/common/verify-editor.sh "$EDITOR_NAME" --setup

echo "=== starting the recorder ==="
# --windowclass is deliberately EMPTY, and that is preserved end to end - an
# unset matcher would fall back to the gnome-calculator demo default, an empty
# one means "match on title alone".  Studio needs it: its frame and its shaped
# "Content window" helper share WM_CLASS "jetbrains-studio", the helper is
# 1442x927 - larger than the frame - and every window lookup in this project
# takes the largest match.
./record-macro.py \
    --script applications/codeeditors/script.md \
    --startcommand 'androidstudio /root/project' \
    --windowtitle 'project' \
    --windowclass '' \
    "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" &
RECORDER=$!

# Studio takes appreciably longer than an Electron editor to put its first
# window up, and the recorder has to be armed before the driver's first click.
sleep 12

bash "applications/codeeditors/${EDITOR_NAME}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

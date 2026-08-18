#!/usr/bin/env bash
# Record applications/codeeditors/eclipse/eclipse.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first.  Eclipse needs that more than most: its first block is
# the workspace-launcher dialog, the Welcome page and an empty Package Explorer,
# and none of the three appear against a workspace that has been opened once.
# It also needs install.sh to restore configuration/ from the copy taken at
# unpack time - the recent-workspace list lives there, not in $HOME, and a
# second run would otherwise draw an extra "Recent Workspaces" row into the
# launcher dialog that block 1's reference image does not have.
set -euo pipefail

REPO=/home/didi/code/parrot
EDITOR_NAME=eclipse
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash applications/codeeditors/common/verify-editor.sh "$EDITOR_NAME" --setup

echo "=== starting the recorder ==="
# --windowclass eclipse matches the workbench, the launcher dialog, two 200x200
# helpers and a window SWT calls "PartRenderingEngine's limbo" - xdotool's class
# match is case-insensitive, so ("Eclipse","Eclipse") and ("eclipse","Eclipse")
# both answer.  replay.py and check-image.sh take the LARGEST match, which is
# always the 1440x900 workbench; record-macro.py takes the first, which is what
# drive-scenario.sh's CP() asserts the size for.
#
# Neither side resizes anything at startup, and that is load-bearing rather than
# lucky: both record-macro.py and replay.py look for the window one second after
# launching the start command, and Eclipse takes four seconds to map its first.
# Finding nothing, they skip the resize - so the 690x290 launcher dialog is left
# at the size fluxbox gave it instead of being blown up to full screen.
./record-macro.py \
    --script applications/codeeditors/script.md \
    --startcommand 'eclipse-run' \
    --windowtitle 'Eclipse' \
    --windowclass eclipse \
    "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" &
RECORDER=$!

# The recorder launches Eclipse and arms xmacrorec2; the driver's own opening
# sleep waits out the launcher dialog, so this only has to cover xmacrorec2.
sleep 12

bash "applications/codeeditors/${EDITOR_NAME}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

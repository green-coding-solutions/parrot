#!/usr/bin/env bash
# Record applications/codeeditors/jupyterlab/jupyterlab.parrot end to end.
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first.  Both halves of this editor need it: Firefox's welcome
# modal only appears against a profile that has never been used, and
# JupyterLab's "official Jupyter news" prompt only against a workspace that has
# never answered it.
#
# It matters more here than elsewhere, because a Firefox killed rather than
# closed leaves a crash flag behind and reopens with an about:sessionrestore tab
# in front of JupyterLab - a second tab that no reference image has.
set -euo pipefail

REPO=/home/didi/code/parrot
EDITOR_NAME=jupyterlab
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash applications/codeeditors/common/verify-editor.sh "$EDITOR_NAME" --setup

echo "=== starting the recorder ==="
# Class rather than title: the window title tracks the page title, so it is
# "JupyterLab - Mozilla Firefox" at block 1 and "price_calcul... - JupyterLab -
# Mozilla Firefox" by block 2.  The class is ("Navigator", "firefox") and
# xdotool's class match is case-insensitive across both fields, so `firefox`
# also matches a 10x10 helper - which is why every lookup in this project takes
# the largest match, and why drive-scenario.sh's CP() asserts the size.
./record-macro.py \
    --script applications/codeeditors/script.md \
    --startcommand 'jupyterlab' \
    --windowtitle 'Mozilla Firefox' \
    --windowclass firefox \
    "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" &
RECORDER=$!

# The recorder launches Firefox and arms xmacrorec2; the driver's own opening
# sleep waits out the page load, so this only has to cover xmacrorec2.
sleep 12

bash "applications/codeeditors/${EDITOR_NAME}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

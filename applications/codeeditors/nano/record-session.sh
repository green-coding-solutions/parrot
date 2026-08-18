#!/usr/bin/env bash
# Record applications/codeeditors/vim/vim.parrot end to end.
set -euo pipefail

REPO=/home/didi/code/parrot
EDITOR_NAME=nano
cd "$REPO"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash applications/codeeditors/common/verify-editor.sh "$EDITOR_NAME" --setup

echo "=== starting the recorder ==="
# The window is the xterm, not nano - it has no window of its own.  Only one
# xterm is ever mapped, so the class alone identifies it.
./record-macro.py \
    --script applications/codeeditors/script.md \
    --startcommand 'nano-term' \
    --windowtitle 'nano-benchmark' \
    --windowclass 'xterm' \
    "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" &
RECORDER=$!

sleep 10

bash "applications/codeeditors/${EDITOR_NAME}/drive-scenario.sh"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/codeeditors/${EDITOR_NAME}/${EDITOR_NAME}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

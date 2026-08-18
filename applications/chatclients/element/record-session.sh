#!/usr/bin/env bash
# Record applications/chatclients/element/element.parrot end to end.
#
# Tears both containers down and rebuilds them through the scenario's own
# setup-commands first. A recording made against containers that have already
# been driven once is a recording of the second run: the account has already
# joined the lobby, the reply and the reaction are already on the anchor
# message, the drip burst is already in the firehose room, and the reference
# images show a state the first replay will never be in.
#
# That matters more here than in the other groups, because the state lives on
# the SERVER. Re-running against a dirty homeserver is not a stale file on
# disk - it is a corpus that no longer matches the manifest the smoke test
# checks, and the smoke test runs as part of the rebuild, so it catches it.
set -euo pipefail

REPO=/home/didi/code/parrot
CLIENT=element
cd "$REPO"

echo "=== rebuilding both containers from usage_scenario.yml ==="
bash "applications/chatclients/common/setup-container.sh" "$CLIENT"

echo "=== starting the recorder ==="
# windowclass `element` is the MAIN window's res_name. NOT `element-desktop`,
# which is the binary, the package, the PATH command and the WM_CLASS of
# Electron's startup error dialog - but not of the main window. See
# MEASUREMENTS.md; guessing it would pin and match nothing, silently.
#
# The startcommand is the wrapper installed by install.sh: it drops to uid 1001,
# starts a session bus and unlocks a secret service. Element crash-loops with no
# window as root, and stops on an "unsupported keyring" modal without the rest.
./record-macro.py \
    --script applications/chatclients/script.md \
    --startcommand 'element-desktop' \
    --windowtitle 'Element' \
    --windowclass element \
    "applications/chatclients/${CLIENT}/${CLIENT}.parrot" &
RECORDER=$!

# The recorder launches the client and arms xmacrorec2; give both time to come
# up before any event is sent, or the first block is recorded without its
# opening keystrokes. Same 20 s as nheko, deliberately: this is measured time,
# so a client with a longer head burns more energy for no reason of its own.
# Element's actual readiness is waited for in drive-scenario.sh, which polls the
# screen rather than guessing.
sleep 20

bash "applications/chatclients/${CLIENT}/drive-scenario.sh"

# STOP THE RECORDER. xmacrorec2 exits on the stop keysym and on nothing else, so
# without this `wait` below blocks forever and the run looks like it is still
# recording long after the last checkpoint was written. That happened once and
# cost a night: the driver had finished at 23:12 and the script was still
# sitting in `wait` the next morning.
#
# The settle first, because the stop key must not arrive before the last
# checkpoint's screenshot has been captured.
sleep 5
docker exec -e DISPLAY=:99 window-container \
    xdotool key --clearmodifiers "${STOP_KEYSYM:-Pause}" || true

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "applications/chatclients/${CLIENT}/${CLIENT}.parrot" \
    | sed 's/^/  checkpoints: /'
ls -1 "applications/chatclients/${CLIENT}/${CLIENT}"-check-*.png 2>/dev/null \
    | wc -l | sed 's/^/  screenshots: /'

echo "=== ground truth (the server, not the screenshots) ==="
TRUTH() {
    docker exec matrix-container python3 \
        /tmp/repo/applications/chatclients/common/matrix-truth.py \
        --homeserver http://127.0.0.1:8008 "$@" 2>&1
}
echo "-- what the account sent in Windvane Deployment"
TRUTH sent --room windvane-deployment | sed 's/^/    /'
echo "-- reactions"
TRUTH reactions --room windvane-deployment | sed 's/^/    /'
echo "-- edits"
TRUTH edits --room windvane-deployment | sed 's/^/    /'
echo "-- join/leave"
TRUTH membership | sed 's/^/    /'
echo "-- the drip burst"
TRUTH drip | sed 's/^/    /'

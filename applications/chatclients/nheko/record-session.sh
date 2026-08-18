#!/usr/bin/env bash
# Record applications/chatclients/nheko/nheko.parrot end to end.
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
CLIENT=nheko
cd "$REPO"

echo "=== rebuilding both containers from usage_scenario.yml ==="
bash "applications/chatclients/common/setup-container.sh" "$CLIENT"

echo "=== starting the recorder ==="
# windowclass nheko matches the main window; both halves of WM_CLASS are the
# same string, so this is unambiguous - see MEASUREMENTS.md. The startcommand
# is the wrapper installed by install.sh, which supplies the session bus and
# the unlocked keyring nheko needs to find its seeded session.
./record-macro.py \
    --script applications/chatclients/script.md \
    --startcommand 'nheko' \
    --windowtitle 'nheko' \
    --windowclass nheko \
    "applications/chatclients/${CLIENT}/${CLIENT}.parrot" &
RECORDER=$!

# The recorder launches the client and arms xmacrorec2; give both time to come
# up before any event is sent, or the first block is recorded without its
# opening keystrokes. nheko needs longer than a word processor: the wrapper has
# to start a session bus and unlock the keyring before the binary even runs.
sleep 20

bash "applications/chatclients/${CLIENT}/drive-scenario.sh"

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

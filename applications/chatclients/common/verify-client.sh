#!/usr/bin/env bash
# Replay a recorded macro in fresh containers and report what happened.
#
#   verify-client.sh <client> [--no-checks]
#
# The setup mirrors the client's usage_scenario.yml by READING it, the same way
# setup-container.sh does, rather than by restating it here. A verification
# whose setup differs from the benchmark's verifies nothing.
#
# Four things are reported, and all four matter:
#
#   1. PASS/FAIL per checkpoint, with the WORST RMSE values - not the pass
#      count. A check that passes at 0.195 against a 0.2 threshold will fail on
#      another machine.
#   2. Whether any consecutive checkpoints are byte-identical. A recording that
#      did nothing replays perfectly: identical references match identical
#      captures and every check passes. Three identical images in a row means
#      the run stopped doing anything at that point.
#   3. The ground truth, from matrix-truth.py. This is the only one that can
#      tell you the run did the work rather than that it looked like it did.
#   4. The drip sequence, separately, because it is the one block whose failure
#      mode is "the client sat still for two minutes and nothing arrived" -
#      which looks identical to a successful idle measurement.
set -uo pipefail

REPO=/home/didi/code/parrot
CLIENT="${1:?usage: verify-client.sh <client> [--no-checks]}"
shift || true
cd "$REPO"

R=/tmp/repo/applications/chatclients
MACRO="${R}/${CLIENT}/${CLIENT}.parrot"
LOG=/tmp/replay-${CLIENT}.log

if [[ ! -f "applications/chatclients/${CLIENT}/${CLIENT}.parrot" ]]; then
    echo "no recording at applications/chatclients/${CLIENT}/${CLIENT}.parrot" >&2
    exit 1
fi

echo "=== rebuilding fresh containers from usage_scenario.yml ==="
bash "${REPO}/applications/chatclients/common/setup-container.sh" "$CLIENT" >/dev/null

echo "=== replaying ${CLIENT}.parrot ==="
docker exec -e DISPLAY=:99 window-container \
    python3 /usr/local/bin/replay.py "$@" "$MACRO" 2>&1 | tee "$LOG"

echo
echo "=== checks ==="
pass=$(grep -c "PASS ref=" "$LOG" 2>/dev/null || echo 0)
fail=$(grep -ci "FAIL ref=" "$LOG" 2>/dev/null || echo 0)
echo "  PASS ${pass}   FAIL ${fail}"
echo "  worst RMSE:"
# The exponent is part of the number: a near-perfect match arrives as
# `rmse=1.24202e-05`, and a pattern of [0-9.]+ truncates that to `1.24202`,
# which then sorts as the WORST result when it is in fact the best in the run.
grep "\[check-image\]" "$LOG" 2>/dev/null \
    | grep -oE "rmse=[0-9.]+([eE][-+]?[0-9]+)?" \
    | sort -t= -k2 -gr | head -3 | sed 's/^/    /' || echo "    (none reported)"

echo
echo "=== identical consecutive checkpoints ==="
# A block that did nothing produces a reference identical to the one before it,
# and then replays perfectly for ever.
prev=''; prevname=''; dupes=0
for png in $(ls -1 "applications/chatclients/${CLIENT}/${CLIENT}"-check-*.png 2>/dev/null); do
    sum=$(sha256sum "$png" | cut -d' ' -f1)
    if [[ "$sum" == "$prev" ]]; then
        echo "    $(basename "$prevname") == $(basename "$png")"
        dupes=$((dupes + 1))
    fi
    prev="$sum"; prevname="$png"
done
[[ $dupes -eq 0 ]] && echo "    none - every checkpoint differs from the one before it"

echo
echo "=== ground truth (the server, not the screenshots) ==="
TRUTH() {
    docker exec matrix-container python3 \
        "${R}/common/matrix-truth.py" --homeserver http://127.0.0.1:8008 "$@" 2>&1
}
echo "-- rooms"
TRUTH summary | sed 's/^/    /'
echo "-- what the account sent in Windvane Deployment"
TRUTH sent --room windvane-deployment | sed 's/^/    /'
echo "-- reactions"
TRUTH reactions --room windvane-deployment | sed 's/^/    /'
echo "-- edits"
TRUTH edits --room windvane-deployment | sed 's/^/    /'
# WHICH event the reply, reaction and edit landed on. The three lines above all
# pass when a reaction is attached to the reply's quoted copy of the anchor
# rather than to the anchor itself, and nothing on screen shows the difference.
# The anchor is from @nadia:parrot.test; the reply is from the account.
echo "-- what the reply/reaction/edit actually TARGET"
TRUTH targets --room windvane-deployment | sed 's/^/    /'
echo "-- join/leave"
TRUTH membership | sed 's/^/    /'
echo "-- the drip burst"
TRUTH drip | sed 's/^/    /'

echo
echo "=== done: ${CLIENT} ==="

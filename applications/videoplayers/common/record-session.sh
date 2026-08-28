#!/usr/bin/env bash
# Record one video player's .parrot end to end.
#
#   common/record-session.sh <app>
#
# Tears the container down and rebuilds it through the scenario's own
# setup-commands first, so that what gets recorded is what gets measured. It
# matters more here than it looks: several entrants remember a per-file resume
# position, so a recording made against a container that has already been driven
# once starts clip 01 somewhere other than its first frame - and every checkpoint
# after block 1 is then against a different part of the film.
set -euo pipefail

REPO=/home/didi/code/parrot
APP="${1:?usage: record-session.sh <app>}"
GROUP="applications/videoplayers"
cd "$REPO"

CONF="${GROUP}/${APP}/driver.conf"
[[ -f "$CONF" ]] || { echo "no driver.conf for ${APP}" >&2; exit 1; }
# shellcheck source=/dev/null
source "$CONF"
: "${CLASS:?driver.conf must set CLASS}"

echo "=== rebuilding the container from usage_scenario.yml ==="
bash "${GROUP}/common/setup-container.sh" "$APP"

echo "=== starting the recorder ==="
# --startcommand is the generated launcher, never the bare binary. The launcher
# is where the corpus playlist, the video output and the entrant's own flags
# live, and it is the same file the benchmark runs - a bare binary here would
# record a session against a different player configuration than the one
# usage_scenario.yml measures.
./record-macro.py \
    --script "${GROUP}/script.md" \
    --startcommand "/usr/local/bin/parrot-${APP}" \
    --windowclass "$CLASS" \
    "${GROUP}/${APP}/${APP}.parrot" &
RECORDER=$!

# The recorder launches the player and arms xmacrorec2. Video players are slower
# off the mark than terminals - a toolkit, a session bus and a demuxer opening a
# 7 MB file - so this is generous on purpose; the driver's own LOAD_WAIT then
# waits for the first frame.
sleep 12

bash "${GROUP}/common/drive-scenario.sh" "$APP"

wait "$RECORDER" || true
echo "=== recorded ==="
grep -c '^check ' "${GROUP}/${APP}/${APP}.parrot" | sed 's/^/  checkpoints: /'
ls -1 "${GROUP}/${APP}/${APP}"-check-*.png 2>/dev/null | wc -l | sed 's/^/  screenshots: /'

# Ground truth. A video player writes no document, so the evidence that the
# blocks actually ran is the corpus's own burnt-in labels: every reference image
# carries the name of the clip that was on screen when it was taken, and the
# order of those names across the twenty-two images is the scenario.
echo "=== clip labels in the reference images ==="
echo "  (read these against script.md: 01 through block 14, then 02,03,04,05,06,05,06,06)"

# The only evidence that audio was decoded at all. No screenshot can show it, and
# an entrant that silently failed to open a device would otherwise look identical
# to one that played both tracks.
echo "=== audio ==="
docker exec window-container pactl list short sink-inputs 2>&1 | sed 's/^/  /' \
    || echo "  no sink-input: the player never delivered audio"

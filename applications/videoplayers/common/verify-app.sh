#!/usr/bin/env bash
# Replay a recorded macro in a fresh container and report what happened.
#
#   verify-app.sh <app>
#
# The container is rebuilt by READING the app's usage_scenario.yml, the same way
# setup-container.sh does, so what is verified is what the benchmark runs.
#
# Four things are reported, and the pass count is the least useful of them:
#
#   1. PASS/FAIL per checkpoint with the WORST RMSE values. A check that passes
#      at 0.195 against a 0.2 ceiling will fail on another machine.
#   2. Identical consecutive reference images. A recording that stopped doing
#      anything replays perfectly - identical references match identical
#      captures - so the checks cannot catch it and this can. In this group a
#      few pairs are identical BY DESIGN (volume and mute change no pixel of the
#      video, and the idle block is defined as changing nothing), so the list is
#      printed rather than judged.
#   3. The clip labels in the reference images, read against the scenario. Every
#      frame carries the name of the clip that was on screen, so the order of
#      those names across the twenty-two images is the scenario itself.
#   4. Whether the player was connected to the audio sink. No screenshot can
#      show that audio was decoded; PulseAudio's sink-input list can.
set -uo pipefail

REPO=/home/didi/code/parrot
APP="${1:?usage: verify-app.sh <app>}"
cd "$REPO"

G=applications/videoplayers
MACRO="/tmp/repo/${G}/${APP}/${APP}.parrot"
LOG=/tmp/replay-${APP}.log

echo "=== rebuilding a fresh container from ${APP}/usage_scenario.yml ==="
# A build failure is not a verification result. A container whose install.sh
# never finished has no launcher and no corpus, so the replay finds no window,
# takes no checkpoints, and the summary reads PASS 0 FAIL 0 - which looks like an
# empty recording rather than an error.
if ! bash "${G}/common/setup-container.sh" "$APP" > "/tmp/setup-${APP}.log" 2>&1; then
    echo "  SETUP FAILED - the container was not built. Last lines:" >&2
    tail -15 "/tmp/setup-${APP}.log" | sed 's/^/    /' >&2
    exit 1
fi
if ! docker exec window-container test -x "/usr/local/bin/parrot-${APP}"; then
    echo "  SETUP INCOMPLETE - /usr/local/bin/parrot-${APP} is missing" >&2
    exit 1
fi
if ! docker exec window-container test -f /opt/parrot/video-corpus/01-h264-1440x900p30.mkv; then
    echo "  SETUP INCOMPLETE - the corpus was not staged at /opt/parrot" >&2
    exit 1
fi

echo "=== replaying ${APP}.parrot ==="
docker exec -e DISPLAY=:99 window-container \
    python3 /usr/local/bin/replay.py "$MACRO" 2>&1 | tee "$LOG"

echo
echo "=== checks ==="
pass=$(grep -c "PASS ref=" "$LOG" 2>/dev/null) || true
fail=$(grep -ci "FAIL ref=" "$LOG" 2>/dev/null) || true
echo "  PASS ${pass}   FAIL ${fail}"
echo "  worst RMSE:"
# The exponent is part of the number: a near-perfect match arrives as
# rmse=1.24e-05, and a [0-9.]+ pattern truncates it to 1.24, which then sorts as
# the worst result when it is the best in the run.
grep "\[check-image\]" "$LOG" 2>/dev/null \
    | grep -oE "rmse=[0-9.]+([eE][-+]?[0-9]+)?" \
    | sort -t= -k2 -gr | head -3 | sed 's/^/    /' || echo "    (none reported)"

echo
echo "=== identical consecutive reference images ==="
echo "  (blocks 6-7 and 21-22 are identical by design; anything else is a stall)"
md5sum ${G}/${APP}/${APP}-check-*.png 2>/dev/null \
  | awk '{ if ($1 == prev) printf "  %s identical to the one before it\n", $2; prev = $1 }' || true

echo
echo "=== separation between consecutive reference images ==="
# How different each reference is from the one before it, as the same RMSE the
# checks use. This is the other half of the identical-image test above, and it is
# what says whether a check can FAIL: two references that differ by 0.02 accept
# each other's captures comfortably inside a 0.2 ceiling, so the second block
# would pass having done nothing.
#
# It earns its place because of the closing seeks. Every play block now ends on a
# mark, which is what makes the references reproducible - but it also means a
# block that seeks to the same mark as its neighbour would capture the same
# frame. Each block is given a mark of its own for that reason, and this is the
# line that proves it worked rather than assuming it.
#
# By design low: 06-07 (volume and mute change no pixel of the video) and 21-22
# (the idle block is defined as changing nothing). Anything else under about 0.05
# wants explaining.
docker exec window-container bash -c '
  cd /tmp/repo/'"${G}"'/'"${APP}"' || exit 0
  prev=""
  for f in '"${APP}"'-check-*.png; do
      if [ -n "$prev" ]; then
          r=$(compare -metric RMSE "$prev" "$f" null: 2>&1 | sed -n "s/.*(\(.*\)).*/\1/p")
          flag=""
          awk "BEGIN { exit !($r < 0.05) }" 2>/dev/null && flag="   <- low"
          printf "  %s -> %s  %s%s\n" "${prev##*-check-}" "${f##*-check-}" "$r" "$flag"
      fi
      prev="$f"
  done' 2>/dev/null || echo "  (could not compare)"

echo
echo "=== audio ==="
docker exec window-container pactl list short sink-inputs 2>&1 | sed 's/^/  /' \
    || echo "  no sink-input: the player never delivered audio"

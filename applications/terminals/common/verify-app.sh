#!/usr/bin/env bash
# Replay a recorded macro in a fresh container and report what happened.
#
#   verify-app.sh <app> [--normalized] [--no-checks]
#
# The setup mirrors the app's usage_scenario.yml by READING it, the same way
# setup-container.sh does, rather than by restating it here. The email client
# group keeps a hand-written copy in its verify script and that copy drifts;
# a verification whose setup differs from the benchmark's verifies nothing.
#
# Three things are reported, and all three matter:
#
#   1. PASS/FAIL per checkpoint, with the WORST RMSE values - not the pass
#      count. A check that passes at 0.195 against a 0.2 threshold will fail on
#      another machine.
#   2. Whether any consecutive checkpoints are byte-identical. A recording that
#      did nothing replays perfectly: identical references match identical
#      captures and every check passes. Three identical images in a row means
#      the run stopped doing anything at that point.
#   3. The ground truth, from the corpus's own verify.sh. This is the only one
#      that can tell you the run did the work rather than that it looked like it
#      did - and in this group it is not optional. A terminal leaves no file
#      behind, and its output scrolls away, so a screenshot proves almost
#      nothing on its own.
set -uo pipefail

REPO=/home/didi/code/parrot
APP="${1:?usage: verify-app.sh <app> [--normalized] [--no-checks]}"
shift || true
cd "$REPO"

# --normalized verifies the time-normalized variant instead: the padded
# recording, replayed in a container built from usage_scenario_normalized.yml.
# The reference images are shared - normalizing only inserts idle before each
# checkpoint - so a normalized run is checked against exactly the same
# screenshots and the same ground truth as the ordinary one.
VARIANT=""
if [[ "${1:-}" == "--normalized" ]]; then
    VARIANT="-normalized"
    shift
    export SCENARIO_OVERRIDE="${REPO}/applications/terminals/${APP}/usage_scenario_normalized.yml"
fi

R=/tmp/repo/applications/terminals
MACRO="${R}/${APP}/${APP}${VARIANT}.parrot"
LOG=/tmp/replay-${APP}${VARIANT}.log

echo "=== rebuilding a fresh container from $(basename "${SCENARIO_OVERRIDE:-usage_scenario.yml}") ==="
# ABORT IF THE BUILD FAILED, and do not swallow its output.
#
# This used to be `... >/dev/null` with no exit check, and the failure mode was
# genuinely misleading: a container whose install.sh never completed has no
# /usr/local/bin/parrot-<app> and no corpus, so the replay finds no window, exits
# with zero checkpoints, and the summary reads `PASS 0   FAIL 0` - which looks
# like an empty recording rather than an error. gnome-terminal hit exactly that
# and its row said `0 0 ? NO RESULT` next to eight apps that had passed.
#
# A build failure is not a verification result. Fail loudly instead.
if ! bash "${REPO}/applications/terminals/common/setup-container.sh" "$APP" > /tmp/setup-${APP}.log 2>&1; then
    echo "  SETUP FAILED - the container was not built. Last lines:" >&2
    tail -15 "/tmp/setup-${APP}.log" | sed 's/^/    /' >&2
    exit 1
fi
# Even a zero exit is not proof: assert the two things the run depends on.
if ! docker exec window-container test -x "/usr/local/bin/parrot-${APP}"; then
    echo "  SETUP INCOMPLETE - /usr/local/bin/parrot-${APP} is missing" >&2
    tail -15 "/tmp/setup-${APP}.log" | sed 's/^/    /' >&2
    exit 1
fi
if ! docker exec window-container test -x /opt/parrot/corpus/verify.sh; then
    echo "  SETUP INCOMPLETE - the corpus was not staged at /opt/parrot" >&2
    exit 1
fi

echo "=== replaying ${APP}${VARIANT}.parrot ==="
docker exec -e DISPLAY=:99 window-container \
    python3 /usr/local/bin/replay.py "$@" "$MACRO" 2>&1 | tee "$LOG"

echo
echo "=== checks ==="
# `grep -c` already prints 0 when it matches nothing, and then exits 1 - so
# `grep -c ... || echo 0` appends a SECOND zero and the variable becomes "0\n0",
# which prints as a stray line under the summary. Let grep report the count and
# swallow only its exit status.
pass=$(grep -c "PASS ref=" "$LOG" 2>/dev/null) || true
fail=$(grep -ci "FAIL ref=" "$LOG" 2>/dev/null) || true
echo "  PASS ${pass}   FAIL ${fail}"
echo "  worst RMSE:"
# The exponent is part of the number. check-image.sh prints values in whatever
# form printf gives it, so a near-perfect match arrives as `rmse=1.24202e-05` -
# and a pattern of [0-9.]+ truncates that to `1.24202`, which then sorts as the
# WORST result when it is in fact the best in the run. Collabora hit exactly
# that: a genuine worst of 0.052 was reported as 1.24.
#
# This line is the one the loop says to read INSTEAD of the pass count, so it
# has to be right. Anchor on the [check-image] lines too - this script tees its
# own summary into the same log, and re-grepping the log would otherwise pick
# up the numbers it just printed.
grep "\[check-image\]" "$LOG" 2>/dev/null \
    | grep -oE "rmse=[0-9.]+([eE][-+]?[0-9]+)?" \
    | sort -t= -k2 -gr | head -3 | sed 's/^/    /' || echo "    (none reported)"

echo
echo "=== identical consecutive checkpoints ==="
# A recording that stopped doing anything is perfectly reproducible, so this is
# not something the screenshot checks can catch.
md5sum applications/terminals/${APP}/${APP}-check-*.png 2>/dev/null \
  | awk '{ if ($1 == prev) { run++ } else { run = 1 }
           if (run >= 2) printf "  %s identical to the one before it\n", $2
           prev = $1 }' || true

echo
echo "=== ground truth ==="
# A terminal emulator writes no document, so there is nothing on disk afterwards
# to open and count - which is exactly why the corpus scripts each append a line
# to /tmp/parrot-term.log as they finish, and why block 16 is checked through the
# X PRIMARY selection. verify.sh re-reads both and prints one line per block plus
# a final RESULT PASS / RESULT FAIL.
#
# This matters more here than in any other group. A screenshot of a terminal
# whose output has already scrolled past is indistinguishable from a screenshot
# of a terminal that printed nothing at all, so the image checks alone cannot
# tell a working run from a run where every keystroke went to a window that was
# not focused. The log can.
#
# Run it with DISPLAY set: the selection half of the check talks to the X server.
# Captured once and echoed, rather than run twice - block 16's check reads a live
# X selection, so a second run is not guaranteed to agree with the first.
truth_out="$(docker exec -e DISPLAY=:99 window-container /opt/parrot/corpus/verify.sh 2>&1)"
printf '%s\n' "$truth_out" | sed 's/^/  /'

truth="$(printf '%s\n' "$truth_out" | grep -E '^RESULT ' | tail -1)"
case "$truth" in
    "RESULT PASS") echo "  ground truth: PASS" ;;
    "RESULT FAIL") echo "  ground truth: FAIL - the run did not do the work" ;;
    *)             echo "  ground truth: NO RESULT - verify.sh did not run" ;;
esac

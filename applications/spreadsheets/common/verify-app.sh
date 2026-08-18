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
#   3. The ground truth, from check-result.sh. This is the only one that can
#      tell you the run did the work rather than that it looked like it did.
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
    export SCENARIO_OVERRIDE="${REPO}/applications/spreadsheets/${APP}/usage_scenario_normalized.yml"
fi

R=/tmp/repo/applications/spreadsheets
MACRO="${R}/${APP}/${APP}${VARIANT}.parrot"
LOG=/tmp/replay-${APP}${VARIANT}.log

echo "=== rebuilding a fresh container from $(basename "${SCENARIO_OVERRIDE:-usage_scenario.yml}") ==="
bash "${REPO}/applications/spreadsheets/common/setup-container.sh" "$APP" >/dev/null

echo "=== replaying ${APP}${VARIANT}.parrot ==="
docker exec -e DISPLAY=:99 window-container \
    python3 /usr/local/bin/replay.py "$@" "$MACRO" 2>&1 | tee "$LOG"

echo
echo "=== checks ==="
pass=$(grep -c "PASS ref=" "$LOG" 2>/dev/null || echo 0)
fail=$(grep -ci "FAIL ref=" "$LOG" 2>/dev/null || echo 0)
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
md5sum applications/spreadsheets/${APP}/${APP}-check-*.png 2>/dev/null \
  | awk '{ if ($1 == prev) { run++ } else { run = 1 }
           if (run >= 2) printf "  %s identical to the one before it\n", $2
           prev = $1 }' || true

echo
echo "=== ground truth ==="
# The expected PDF page count is per-app. The workbook carries print ranges, so
# an application that honours them lands on 9 - measured for LibreOffice Calc.
# One that ignores them prints the whole 20,000-row used range instead and comes
# back in the hundreds, which is a finding rather than a threshold to widen.
# Apps that differ carry the number beside their scenario.
PDF_PAGES=9
[[ -f "applications/spreadsheets/${APP}/expected-pdf-pages" ]] &&
    PDF_PAGES="$(tr -dc '0-9' < "applications/spreadsheets/${APP}/expected-pdf-pages")"
bash "${REPO}/applications/spreadsheets/common/check-result.sh" window-container "$PDF_PAGES"

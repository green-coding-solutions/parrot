#!/usr/bin/env bash
# Run the terminal scenarios through the local Green Metrics Tool.
#
#   common/gmt-run.sh [--plain] [app ...]
#
# Default is the TIME-NORMALIZED scenarios, because those are the ones whose
# numbers are comparable: every block is padded to the slowest entrant's, so all
# nine runs are the same wall-clock length and an app that finishes its work
# sooner spends the remainder idle. That is exactly the comparison wanted -
# energy to do the same job in the same time. `--plain` runs the unpadded
# scenarios instead, which are useful for seeing raw duration but not for
# comparing energy.
#
# JUDGING A RUN. GMT exits 0 even when the flow failed, so the exit code says
# nothing. A run is good only if all three hold:
#
#   MEASUREMENT SUCCESSFULLY COMPLETED   appears once
#   FAIL ref=                            appears zero times
#   PASS ref=                            appears CHECKS times (16 here)
#
# Preconditions, each of which has cost a run before:
#   * no window-container left behind - GMT refuses to start if one is up
#   * --dev-no-system-checks=check_ssh_session, or runner.py aborts with
#     PermissionError: /etc/ssh/sshd_config before the scenario starts
#   * the image must be on the registry; GMT pulls it unconditionally, and the
#     local-image fallback is gated on a tty (which is itself measurement
#     overhead and therefore wrong for numbers you report)
set -uo pipefail

GMT=/home/didi/code/green-metrics-tool
REPO=/home/didi/code/parrot
CHECKS=16
OUT=/tmp/claude-1000/-home-didi-code-parrot/e0961f5a-c6da-4f82-963c-c6f942b35be8/scratchpad/gmt
mkdir -p "$OUT"

VARIANT="_normalized"
LABEL="time-normalized"
if [[ "${1:-}" == "--plain" ]]; then VARIANT=""; LABEL="unpadded"; shift; fi

APPS=("$@")
[[ ${#APPS[@]} -eq 0 ]] && APPS=(xterm urxvt mlterm pterm st gnome-terminal konsole alacritty kitty)

echo "=== GMT sweep: ${LABEL} scenarios, ${#APPS[@]} apps ==="
printf '%-16s %-10s %-8s %-8s %s\n' app measurement pass fail verdict
printf '%-16s %-10s %-8s %-8s %s\n' ---------------- ---------- -------- -------- -------

for a in "${APPS[@]}"; do
    scen="applications/terminals/${a}/usage_scenario${VARIANT}.yml"
    if [[ ! -f "${REPO}/${scen}" ]]; then
        printf '%-16s %s\n' "$a" "(no ${scen})"; continue
    fi
    log="${OUT}/${a}${VARIANT}.log"

    # GMT refuses to start if a window-container is already up, and the record
    # and verify scripts both leave one behind.
    docker rm -f window-container >/dev/null 2>&1

    ( cd "$GMT" && venv/bin/python runner.py \
        --uri "$REPO" --filename "$scen" \
        --dev-no-sleeps --dev-no-system-checks=check_ssh_session ) > "$log" 2>&1

    done_n=$(grep -c "MEASUREMENT SUCCESSFULLY COMPLETED" "$log" 2>/dev/null) || true
    pass_n=$(grep -c "PASS ref=" "$log" 2>/dev/null) || true
    fail_n=$(grep -ci "FAIL ref=" "$log" 2>/dev/null) || true

    verdict="OK"
    [[ "${done_n:-0}" -ne 1 ]]        && verdict="NOT COMPLETED"
    [[ "${fail_n:-0}" -ne 0 ]]        && verdict="CHECK FAILURES"
    [[ "${pass_n:-0}" -ne $CHECKS ]]  && verdict="${verdict} (want ${CHECKS} passes)"

    printf '%-16s %-10s %-8s %-8s %s\n' "$a" "${done_n:-0}" "${pass_n:-0}" "${fail_n:-0}" "$verdict"
done

echo
echo "logs in ${OUT}"

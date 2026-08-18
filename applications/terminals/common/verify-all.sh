#!/usr/bin/env bash
# Replay-verify every recorded emulator and print one comparable summary.
#
#   common/verify-all.sh [app ...]     (default: all seven)
#
# Each app is rebuilt from its own usage_scenario.yml and replayed in a fresh
# container, so this is the same path GMT takes.
#
# WHAT TO READ. Not the pass count - the WORST RMSE. A checkpoint that passes at
# 0.195 against a 0.2 threshold will fail on another machine, and the pass count
# says nothing about how close it came. xterm replayed at RMSE 0 on the
# eighteen-block script, which is a property of terminals rather than luck: no
# antialiasing variation, no blinking cursor, and nothing on screen derived from
# the clock, the hostname or the path.
#
# And read the ground truth, which is the only line that can tell you the run did
# the work rather than that it looked like it did.
set -uo pipefail

REPO=/home/didi/code/parrot
cd "$REPO"
APPS=("$@")
[[ ${#APPS[@]} -eq 0 ]] && APPS=(xterm urxvt gnome-terminal konsole alacritty kitty st)

OUT=/tmp/claude-1000/-home-didi-code-parrot/e0961f5a-c6da-4f82-963c-c6f942b35be8/scratchpad
mkdir -p "$OUT"

printf '%-16s %-6s %-6s %-12s %s\n' app pass fail worst-rmse "ground truth"
printf '%-16s %-6s %-6s %-12s %s\n' ---------------- ------ ------ ------------ ------------
for a in "${APPS[@]}"; do
    if [[ ! -f "applications/terminals/${a}/${a}.parrot" ]]; then
        printf '%-16s %s\n' "$a" "(not recorded)"
        continue
    fi
    log="${OUT}/v-${a}.log"
    bash applications/terminals/common/verify-app.sh "$a" > "$log" 2>&1
    pass=$(grep -oE 'PASS [0-9]+' "$log" | head -1 | awk '{print $2}')
    fail=$(grep -oE 'FAIL [0-9]+' "$log" | head -1 | awk '{print $2}')
    worst=$(grep -A4 'worst RMSE' "$log" | grep -oE 'rmse=[0-9.]+([eE][-+]?[0-9]+)?' | head -1 | cut -d= -f2)
    truth=$(grep -oE 'ground truth: [A-Z ]+' "$log" | tail -1 | cut -d: -f2- | xargs)
    printf '%-16s %-6s %-6s %-12s %s\n' "$a" "${pass:-?}" "${fail:-?}" "${worst:-?}" "${truth:-?}"
done

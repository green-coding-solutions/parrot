#!/usr/bin/env bash
# Rebuild window-container exactly the way an app's usage_scenario.yml does.
#
#   setup-container.sh <app> [--measure]
#
# The setup-commands are read out of the scenario file rather than restated here,
# because a hand-kept copy drifts from the scenario it claims to mirror and then
# the thing that gets recorded is not the thing that gets measured.
#
# --measure additionally installs xprop, which the landmark measuring needs and
# the benchmark does not.  It deletes /usr/bin/xmessage straight afterwards:
# x11-utils pulls xmessage in, fluxbox's fbsetbg fails to set the wallpaper in
# this image and calls xmessage to say so, and the resulting 1017x107 dialog sits
# on the display through the whole session.  Without x11-utils that failure is
# silent, which is what the benchmark sees - so the measuring container has to
# put it back to silent or it is measuring a different screen.
set -euo pipefail

REPO=/home/didi/code/parrot
APP="${1:?usage: setup-container.sh <app> [--measure]}"
MEASURE="${2:-}"
# SCENARIO_OVERRIDE lets verify-app.sh --normalized build the container from
# usage_scenario_normalized.yml instead. The two scenarios are generated from
# one another and differ only in which recording they replay, but reading the
# one actually under test is the whole point of this script.
SCENARIO="${SCENARIO_OVERRIDE:-${REPO}/applications/spreadsheets/${APP}/usage_scenario.yml}"
[[ -f "$SCENARIO" ]] || { echo "no scenario at $SCENARIO" >&2; exit 1; }

cd "$REPO"

# docker-run-args is read out of the scenario too, for the same reason the
# setup-commands are: a container built with different flags from the one the
# benchmark builds is not the container being measured. The Flatpak entrants
# need two `--security-opt` relaxations - seccomp, for the unshare(CLONE_NEWUSER)
# that bubblewrap and therefore every `flatpak run` depends on, and systempaths,
# because Docker's masked /proc stops that namespace mounting a procfs. Neither
# adds a capability; the app runs as uid 1001 so that none is needed. The full
# matrix is in either scenario file.
mapfile -t RUN_ARGS < <(python3 - "$SCENARIO" <<'PY'
import re, shlex, sys
text = open(sys.argv[1]).read()
m = re.search(r'^\s*docker-run-args:\s*\n((?:\s*-\s*.+\n)+)', text, re.M)
if m:
    for line in m.group(1).splitlines():
        for tok in shlex.split(line.split('-', 1)[1].strip(), posix=False):
            print(tok)
PY
)
[[ ${#RUN_ARGS[@]} -gt 0 ]] && echo "  docker-run-args: ${RUN_ARGS[*]}"

docker rm -f window-container >/dev/null 2>&1 || true
docker run -d --name window-container \
    -v "${REPO}:/tmp/repo:ro" -e RESOLUTION=1440x900 --shm-size=1g \
    "${RUN_ARGS[@]}" \
    ribalba/xwindow-server sleep inf >/dev/null

if [[ "$MEASURE" == "--measure" ]]; then
    docker exec window-container bash -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq && apt-get install -y -qq x11-utils >/dev/null 2>&1
        rm -f /usr/bin/xmessage' || true
    echo "  measuring tools installed, xmessage removed"
fi

# Read the setup-commands out of the scenario and run them in order, the way GMT
# would.  No shell: GMT runs each through shlex.split(cmd, posix=False), so this
# reproduces the argv the benchmark will actually see, quotes and all.
python3 - "$SCENARIO" <<'PY'
import shlex, subprocess, sys, re
text = open(sys.argv[1]).read()
block = text.split('setup-commands:', 1)[1].split('\nflow:', 1)[0]
cmds = [m.group(1).strip() for m in re.finditer(r'^\s*-\s*command:\s*(.+)$', block, re.M)]
for c in cmds:
    argv = ['docker', 'exec', 'window-container', *shlex.split(c, posix=False)]
    print(f"  $ {c}")
    r = subprocess.run(argv, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    if out:
        print('\n'.join('    ' + l for l in out.splitlines()[-6:]))
    if r.returncode != 0:
        print(f"    FAILED rc={r.returncode}")
        sys.exit(1)
PY

echo "=== window-container ready for ${APP} ==="

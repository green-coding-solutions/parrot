#!/usr/bin/env bash
# Rebuild the benchmark's containers exactly the way a client's
# usage_scenario.yml does.
#
#   setup-container.sh <client> [--measure]
#
# Unlike the word-processor group's copy this brings up TWO containers and the
# network between them, because half of what the scenario measures is a
# conversation with a server. The homeserver is started first and its
# setup-commands are run to completion before the window container is created,
# which is what GMT's `depends_on` does - and it matters here beyond ordering:
# parrot-bot.py has to be synced and listening before anything can trigger it.
#
# Everything - images, network aliases, docker-run-args, both sets of
# setup-commands - is read out of the scenario file rather than restated here,
# because a hand-kept copy drifts from the scenario it claims to mirror and then
# the thing that gets recorded is not the thing that gets measured.
#
# --measure additionally installs xprop, which the landmark measuring needs and
# the benchmark does not. It deletes /usr/bin/xmessage straight afterwards:
# x11-utils pulls xmessage in, fluxbox's fbsetbg fails to set the wallpaper in
# this image and calls xmessage to say so, and the resulting dialog sits on the
# display through the whole session. Without x11-utils that failure is silent,
# which is what the benchmark sees - so the measuring container has to put it
# back to silent or it is measuring a different screen.
set -euo pipefail

REPO=/home/didi/code/parrot
CLIENT="${1:?usage: setup-container.sh <client> [--measure]}"
MEASURE="${2:-}"
SCENARIO="${SCENARIO_OVERRIDE:-${REPO}/applications/chatclients/${CLIENT}/usage_scenario.yml}"
[[ -f "$SCENARIO" ]] || { echo "no scenario at $SCENARIO" >&2; exit 1; }

cd "$REPO"

NETWORK=parrot-matrix-measure

# --------------------------------------------------------------------------
# Read the scenario once; everything below comes out of this.
# --------------------------------------------------------------------------
eval "$(/usr/bin/python3 - "$SCENARIO" <<'PY'
import shlex, sys, yaml
scenario = yaml.safe_load(open(sys.argv[1]))
services = scenario['services']
matrix, window = services['matrix-container'], services['window-container']

def emit(name, value):
    print(f"{name}={shlex.quote(str(value))}")

emit('MATRIX_IMAGE', matrix['image'])
emit('WINDOW_IMAGE', window['image'])

nets = matrix.get('networks') or {}
aliases = []
if isinstance(nets, dict):
    for cfg in nets.values():
        aliases += (cfg or {}).get('aliases') or []
emit('MATRIX_ALIASES', ' '.join(aliases))

run_args = []
for entry in window.get('docker-run-args') or []:
    run_args += shlex.split(str(entry), posix=False)
emit('WINDOW_RUN_ARGS', ' '.join(run_args))
PY
)"

echo "  matrix image : ${MATRIX_IMAGE}"
echo "  aliases      : ${MATRIX_ALIASES:-<none>}"
echo "  run-args     : ${WINDOW_RUN_ARGS:-<none>}"

run_setup_commands() {  # run_setup_commands <service> <container>
    /usr/bin/python3 - "$SCENARIO" "$1" "$2" <<'PY'
import shlex, subprocess, sys, yaml
scenario, service, container = sys.argv[1], sys.argv[2], sys.argv[3]
cmds = [c['command'] for c in
        (yaml.safe_load(open(scenario))['services'][service].get('setup-commands') or [])]
for command in cmds:
    # No shell: GMT runs each through shlex.split(cmd, posix=False), so this
    # reproduces the argv the benchmark will actually see, quotes and all.
    argv = ['docker', 'exec', container, *shlex.split(command, posix=False)]
    print(f"  $ {command}", flush=True)
    result = subprocess.run(argv, capture_output=True, text=True)
    output = (result.stdout + result.stderr).strip()
    if output:
        print('\n'.join('    ' + line for line in output.splitlines()[-8:]), flush=True)
    if result.returncode != 0:
        print(f"    FAILED rc={result.returncode}")
        sys.exit(1)
PY
}

# --------------------------------------------------------------------------
# Teardown, then the network
# --------------------------------------------------------------------------
docker rm -f window-container matrix-container >/dev/null 2>&1 || true
docker network rm "$NETWORK" >/dev/null 2>&1 || true
docker network create "$NETWORK" >/dev/null

# --------------------------------------------------------------------------
# The homeserver, first and completely
# --------------------------------------------------------------------------
alias_args=()
for a in $MATRIX_ALIASES; do alias_args+=(--network-alias "$a"); done

echo "=== matrix-container ==="
docker run -d --name matrix-container \
    --network "$NETWORK" "${alias_args[@]}" \
    -v "${REPO}:/tmp/repo:ro" \
    "$MATRIX_IMAGE" sleep inf >/dev/null
run_setup_commands matrix-container matrix-container

# --------------------------------------------------------------------------
# The client
# --------------------------------------------------------------------------
echo "=== window-container ==="
read -r -a window_run_args <<< "${WINDOW_RUN_ARGS:-}"
docker run -d --name window-container \
    --network "$NETWORK" \
    -v "${REPO}:/tmp/repo:ro" -e RESOLUTION=1440x900 --shm-size=1g \
    "${window_run_args[@]}" \
    "$WINDOW_IMAGE" sleep inf >/dev/null

if [[ "$MEASURE" == "--measure" ]]; then
    docker exec window-container bash -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq && apt-get install -y -qq x11-utils >/dev/null 2>&1
        rm -f /usr/bin/xmessage' || true
    echo "  measuring tools installed, xmessage removed"
fi

run_setup_commands window-container window-container

echo "=== containers ready for ${CLIENT} ==="

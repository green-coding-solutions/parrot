#!/usr/bin/env bash
# Replay a recorded editor macro in a fresh container, then check the file it
# was supposed to edit.
#
#   verify-editor.sh <editor>            record-free replay + checks + ground truth
#   verify-editor.sh <editor> --setup    bring the container up and stop, leaving
#                                        it running for measuring or recording
#   verify-editor.sh <editor> --no-checks
#                                        replay past screenshot mismatches, for
#                                        debugging a driver
#
# WHY IT READS THE SCENARIO INSTEAD OF MIRRORING IT
#
# The email-client harness keeps a hand-written copy of each client's setup in a
# case statement, and the group's notes record what that costs: the scenario file
# is the production path, the harness is a copy of it, and the two drift - a
# pin-windows argument here, a seeder there, an environment entry that only one
# of them has.  A verification that sets up differently from the benchmark is not
# a verification of the benchmark.
#
# So this reads usage_scenario.yml and runs the window container's own
# setup-commands, in order, with its own environment.  There is nothing to keep
# in sync.  It reproduces GMT's argv handling too - shlex.split(posix=False),
# which keeps quotes as literal characters - so a command that would break under
# GMT breaks here, which is the entire point.
set -euo pipefail

REPO=/home/didi/code/parrot
GMT_PYTHON=/home/didi/code/green-metrics-tool/venv/bin/python
EDITOR_NAME="${1:?usage: verify-editor.sh <editor> [--setup|--no-checks]}"
MODE="${2:-}"
SCENARIO="${REPO}/applications/codeeditors/${EDITOR_NAME}/usage_scenario.yml"
R=/tmp/repo/applications/codeeditors

[[ -f "$SCENARIO" ]] || { echo "no scenario at $SCENARIO" >&2; exit 1; }

# --- read the window-container service out of the scenario -------------------
read_service() {
    "$GMT_PYTHON" - "$SCENARIO" "$1" <<'PY'
import shlex, sys, yaml
scenario, what = sys.argv[1], sys.argv[2]
svc = yaml.safe_load(open(scenario))["services"]["window-container"]
if what == "env":
    for k, v in (svc.get("environment") or {}).items():
        print(f"{k}={v}")
elif what == "image":
    print(svc["image"])
elif what == "setup":
    for entry in svc.get("setup-commands") or []:
        cmd = entry["command"] if isinstance(entry, dict) else entry
        # GMT: d_command = ['docker','exec',name,*shlex.split(cmd, posix=False)]
        # posix=False keeps quotes as literal characters, which is what makes a
        # quoted glob reach the program as a quoted glob.  Reproduce it exactly.
        if isinstance(entry, dict) and entry.get("shell"):
            print("\t".join(["bash", "-c", cmd]))
        else:
            print("\t".join(shlex.split(cmd, posix=False)))
PY
}

IMAGE="$(read_service image)"
mapfile -t ENV_LINES < <(read_service env)
ENV_ARGS=()
for line in "${ENV_LINES[@]}"; do [[ -n "$line" ]] && ENV_ARGS+=(-e "$line"); done

echo "=== container: ${IMAGE} ==="
[[ ${#ENV_LINES[@]} -gt 0 ]] && printf '  env %s\n' "${ENV_LINES[@]}"

docker rm -f window-container >/dev/null 2>&1 || true
docker run -d --name window-container \
    -v "${REPO}:/tmp/repo:ro" --shm-size=1g \
    -p 6080:6080 -p 5900:5900 \
    "${ENV_ARGS[@]}" -e DEBUG=1 \
    "$IMAGE" sleep inf >/dev/null

echo "=== setup-commands ==="
while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    IFS=$'\t' read -r -a cmd <<< "$line"
    printf '  $ %s\n' "${cmd[*]}"
    if ! docker exec window-container "${cmd[@]}" >/tmp/${EDITOR_NAME}-setup.log 2>&1; then
        echo "  SETUP FAILED - last 30 lines:" >&2
        tail -30 /tmp/${EDITOR_NAME}-setup.log >&2
        exit 1
    fi
done < <(read_service setup)

if [[ "$MODE" == "--setup" ]]; then
    echo "=== container is up; watch it at http://localhost:6080/vnc.html ==="
    exit 0
fi

# --- replay ------------------------------------------------------------------
NO_CHECKS=()
[[ "$MODE" == "--no-checks" ]] && NO_CHECKS=(-e REPLAY_IGNORE_CHECKS=1)

echo "=== replay ==="
set +e
docker exec -e DISPLAY=:99 "${NO_CHECKS[@]}" window-container \
    python3 /usr/local/bin/replay.py "$R/${EDITOR_NAME}/${EDITOR_NAME}.parrot" \
    >/tmp/${EDITOR_NAME}-out.log 2>/tmp/${EDITOR_NAME}-err.log
rc=$?
set -e
echo "  replay exit code: $rc"
echo "  passed: $(grep -c 'PASS ref=' /tmp/${EDITOR_NAME}-err.log)  failed: $(grep -ci 'FAIL ref=' /tmp/${EDITOR_NAME}-err.log)"

# A check that passes at 0.195 against a 0.2 threshold has not really passed, and
# the pass count cannot say so.  `|| true` on every diagnostic: this script runs
# under `set -e`, and a grep that legitimately matches nothing would otherwise
# kill the run right here - above the ground-truth check, which is the one thing
# that must always be reached.
echo "--- worst RMSE ---"
{ grep -oE '(PASS|FAIL) ref=[^ ]+ rmse=[0-9.e-]+' /tmp/${EDITOR_NAME}-err.log \
  | sort -t= -k3 -g -r | head -3 | sed 's/^/  /'; } || true
echo "--- notes ---"
{ sed 's/^/  /' /tmp/${EDITOR_NAME}-out.log | head -14; } || true

docker exec window-container bash "$R/common/check-result.sh" || true

# Did the RECORDING do anything?  A replay compares each checkpoint against its
# own reference, so a run of identical references matches a run of identical
# captures and reports a clean pass over blocks that changed nothing.  Three
# editors shipped exactly that.  This runs on the host, against the reference
# images, so it is a statement about the recording rather than about the replay.
echo "--- distinct checkpoints ---"
{ bash "${REPO}/applications/codeeditors/common/check-screens.sh" "$EDITOR_NAME" \
    | sed 's/^/  /'; } || true

# Leave nothing behind.  GMT refuses to start when a container of the same name
# is already up - "Container 'window-container' is already running on system" -
# so a verify run that kept its container makes the very next production run
# fail, several minutes later, with an error that says nothing about this
# script.  --setup is the mode that deliberately keeps it.
docker rm -f window-container >/dev/null 2>&1 || true
echo "=== VERIFICATION COMPLETE ==="

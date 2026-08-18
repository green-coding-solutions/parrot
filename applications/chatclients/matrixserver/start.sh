#!/usr/bin/env bash
# Start the benchmark homeserver and prove it is serving the right corpus.
#
# This is the runtime half of the matrix container: everything here is fast, so
# it is what the prebuilt image runs on every benchmark.  The slow half -
# installing packages and seeding tens of thousands of events - is build.sh,
# which the image bakes in ahead of time.
#
# Safe to run repeatedly.
set -euo pipefail

# readlink -f, so this still resolves when the script is reached through a
# symlink: BASH_SOURCE is then the link's path and ../account.env would not
# exist next to it.  The prebuilt image relies on this - it puts start.sh on
# PATH as /usr/local/bin/parrot-matrixserver-start.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

PG_VERSION="${PARROT_PG_VERSION:-16}"
CONF_DIR=/etc/matrix-synapse
MANIFEST=/var/lib/matrix-synapse/corpus-manifest.json

log() { printf '[matrixserver] %s\n' "$*"; }

log "starting postgresql"
pg_ctlcluster "$PG_VERSION" main start || true

for _ in $(seq 60); do
    runuser -u postgres -- pg_isready -q && break
    sleep 1
done
runuser -u postgres -- pg_isready -q

log "starting synapse"
# The interpreter build.sh actually used. matrix.org's package ships Synapse in
# a virtualenv under /opt/venvs, not in the system Python, and re-deriving the
# choice here could silently pick a different one from the one that generated
# the signing key and the database schema.
if [[ -f /opt/parrot/synapse-paths.env ]]; then
    # shellcheck source=/dev/null
    source /opt/parrot/synapse-paths.env
else
    SYNAPSE_PY=/opt/venvs/matrix-synapse/bin/python
    [[ -x "$SYNAPSE_PY" ]] || SYNAPSE_PY=python3
    log "WARNING: /opt/parrot/synapse-paths.env missing, guessing ${SYNAPSE_PY}"
fi

# Backgrounded here rather than with Synapse's own --daemonize: that flag forks
# and detaches, so a startup failure returns a bare non-zero with an empty log.
# See the note in build.sh.
if ! pgrep -f 'synapse.app.homeserver' >/dev/null 2>&1; then
    setsid runuser -u matrix-synapse -- "$SYNAPSE_PY" -m synapse.app.homeserver \
        --config-path "${CONF_DIR}/homeserver.yaml" \
        >/var/log/matrix-synapse/start.log 2>&1 &
    disown || true
fi

python3 - "$PARROT_MATRIX_PORT" <<'PY'
import socket, sys, time
port = int(sys.argv[1])
deadline = time.monotonic() + 120
while time.monotonic() < deadline:
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=2):
            print(f'[matrixserver] port {port} (synapse) is up', flush=True)
            sys.exit(0)
    except OSError:
        time.sleep(1)
print(f'[matrixserver] port {port} never opened', file=sys.stderr)
sys.exit(1)
PY
rc=$?
if [[ $rc -ne 0 ]]; then
    log "--- start.log ---"
    tail -n 40 /var/log/matrix-synapse/start.log 2>/dev/null | sed 's/^/    /' || true
    log "--- homeserver.log ---"
    tail -n 40 /var/log/matrix-synapse/homeserver.log 2>/dev/null | sed 's/^/    /' || true
    exit 1
fi

if [[ "${PARROT_SKIP_SMOKE:-0}" == "1" ]]; then
    log "skipping smoke test (PARROT_SKIP_SMOKE=1)"
else
    log "running smoke test"
    python3 "${HERE}/smoke_test.py" \
        --homeserver "http://127.0.0.1:${PARROT_MATRIX_PORT}" \
        --user "$PARROT_MATRIX_USER" \
        --password "$PARROT_MATRIX_PASS" \
        --bot "$PARROT_BOT_USER" \
        --manifest "$MANIFEST"
fi

log "ready"

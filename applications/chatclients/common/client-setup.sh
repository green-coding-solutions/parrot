#!/usr/bin/env bash
# Prepare the client container to talk to the benchmark homeserver.
#
# Runs in the window-container after the matrix container has finished its own
# setup. That ordering is guaranteed by `depends_on` in the usage_scenario: GMT
# creates and fully sets up services in dependency order, so by the time this
# runs the corpus exists, Synapse is listening and parrot-bot.py is synced.
#
# Three jobs:
#   1. make sure matrix.parrot.test resolves
#   2. block until the homeserver actually answers
#   3. print the account details and anchors the recording operator needs
#
# There is no CA step here, unlike the email group's copy. The homeserver is
# plain HTTP on a private network - see the note on PARROT_MATRIX_URL in
# account.env for why that compromise is the one that keeps the comparison
# about the client.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

log() { printf '[client-setup] %s\n' "$*"; }

# --------------------------------------------------------------------------
# 1. Name resolution
# --------------------------------------------------------------------------
if getent hosts "$PARROT_MATRIX_HOST" >/dev/null 2>&1; then
    log "$PARROT_MATRIX_HOST resolves to $(getent hosts "$PARROT_MATRIX_HOST" | awk '{print $1}')"
else
    # Fallback for running the containers by hand, without the network alias.
    ip="$(getent hosts matrix-container 2>/dev/null | awk '{print $1}' || true)"
    if [[ -z "$ip" ]]; then
        log "ERROR: neither $PARROT_MATRIX_HOST nor matrix-container resolves."
        log "Is the matrix service on the same Docker network?"
        exit 1
    fi
    log "adding $PARROT_MATRIX_HOST -> $ip to /etc/hosts"
    printf '%s %s\n' "$ip" "$PARROT_MATRIX_HOST" >> /etc/hosts
fi

# --------------------------------------------------------------------------
# 2. Wait for the homeserver
# --------------------------------------------------------------------------
# Not just the TCP port: Synapse accepts connections before it is ready to
# serve, and a client that starts in that window shows a connection error on
# its first screen. /versions answering is the earliest honest signal.
PARROT_MATRIX_HOST="$PARROT_MATRIX_HOST" PARROT_MATRIX_PORT="$PARROT_MATRIX_PORT" python3 - <<'PY'
import json, os, sys, time, urllib.error, urllib.request
host = os.environ['PARROT_MATRIX_HOST']
port = os.environ['PARROT_MATRIX_PORT']
url = f'http://{host}:{port}/_matrix/client/versions'
deadline = time.monotonic() + 600
while time.monotonic() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read())
        print(f'[client-setup] {host}:{port} serving {len(data.get("versions", []))} '
              f'client-server versions', flush=True)
        sys.exit(0)
    except (urllib.error.URLError, OSError):
        time.sleep(2)
print(f'[client-setup] ERROR: {url} never answered', file=sys.stderr)
sys.exit(1)
PY

# --------------------------------------------------------------------------
# 3. Operator information
# --------------------------------------------------------------------------
# Printed so whoever is recording a macro can see the credentials and the
# anchors the scenario refers to, without digging through the corpus.
cat <<EOF
[client-setup] account details for the recording operator:
    homeserver   ${PARROT_MATRIX_URL}
    user id      ${PARROT_MATRIX_ID}
    username     ${PARROT_MATRIX_USER}
    password     ${PARROT_MATRIX_PASS}
    peer         ${PARROT_PEER_ID}      (invited in the "Create room" block)
    bot          ${PARROT_BOT_ID}       (answers \`ping\` and \`drip\`)

[client-setup] rooms the scenario drives, in order:
    Aurora Release        deep history, ${PARROT_MATRIX_MEMBERS:-500} members - the scroll-back and member-list blocks
    Field Photos          images; the newest is reservoir-at-first-light.jpg
    Windvane Deployment   the only room matching the filter \`windvane\`
                          newest message: "Ship it when the smoke tests are green."
                          from Nadia Oyelaran - the reply/react/edit anchor
    Parrot Echo           send \`ping\`, wait for \`pong\`
    #parrot-lobby         NOT joined yet: the scenario joins it, then leaves it
    Parrot Firehose       both idle blocks; send \`drip\` to start the burst
                          of ${PARROT_BOT_DRIP_COUNT:-24} messages, one every ${PARROT_BOT_DRIP_INTERVAL:-5.0}s

[client-setup] the upload block attaches /tmp/parrot.png
[client-setup] ready
EOF

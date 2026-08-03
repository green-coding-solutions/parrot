#!/usr/bin/env bash
# Prepare the client container to talk to the benchmark mail server.
#
# Runs in the window-container after the mail server has finished its own setup.
# That ordering is guaranteed by `depends_on` in the usage_scenario: GMT creates
# and fully sets up services in dependency order, so by the time this runs the
# corpus exists and Dovecot is listening.
#
# Three jobs:
#   1. make sure mail.parrot.test resolves
#   2. trust the server's throwaway CA, without needing a shared volume
#   3. block until IMAP and submission actually answer
set -euo pipefail

# readlink -f, so this still resolves when the script is reached through a
# symlink: BASH_SOURCE is then the link's path and ../account.env would not
# exist next to it.  The prebuilt image relies on this - it puts start.sh on
# PATH as /usr/local/bin/parrot-mailserver-start.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

log() { printf '[client-setup] %s\n' "$*"; }

command -v openssl >/dev/null 2>&1 || {
    log "installing openssl and ca-certificates"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends openssl ca-certificates >/dev/null
}

# --------------------------------------------------------------------------
# 1. Name resolution
# --------------------------------------------------------------------------
if getent hosts "$PARROT_MAIL_HOST" >/dev/null 2>&1; then
    log "$PARROT_MAIL_HOST resolves to $(getent hosts "$PARROT_MAIL_HOST" | awk '{print $1}')"
else
    # Fallback for running the containers by hand, without the network alias.
    ip="$(getent hosts mail-container 2>/dev/null | awk '{print $1}' || true)"
    if [[ -z "$ip" ]]; then
        log "ERROR: neither $PARROT_MAIL_HOST nor mail-container resolves."
        log "Is the mail service on the same Docker network?"
        exit 1
    fi
    log "adding $PARROT_MAIL_HOST -> $ip to /etc/hosts"
    printf '%s %s\n' "$ip" "$PARROT_MAIL_HOST" >> /etc/hosts
fi

# --------------------------------------------------------------------------
# 2. Wait for the server
# --------------------------------------------------------------------------
PARROT_MAIL_HOST="$PARROT_MAIL_HOST" python3 - <<'PY'
import os, socket, sys, time
host = os.environ['PARROT_MAIL_HOST']
ports = {143: 'imap', 993: 'imaps', 587: 'submission'}
deadline = time.monotonic() + 600
pending = dict(ports)
while pending and time.monotonic() < deadline:
    for port in list(pending):
        try:
            with socket.create_connection((host, port), timeout=3):
                print(f'[client-setup] {host}:{port} ({pending[port]}) reachable', flush=True)
                del pending[port]
        except OSError:
            pass
    if pending:
        time.sleep(2)
if pending:
    print(f'[client-setup] ERROR: unreachable on {host}: {pending}', file=sys.stderr)
    sys.exit(1)
PY

# --------------------------------------------------------------------------
# 3. Trust the server's CA
# --------------------------------------------------------------------------
# The mail container mints a throwaway CA on every run, so there is no
# certificate in version control and nothing to keep in sync.  Rather than pass
# it through a shared Docker volume - GMT does not create named volumes, so
# that would need either --allow-unsafe or a manually pre-created volume - the
# client just reads the chain off the live TLS port.  Dovecot is configured to
# send leaf + CA, so the anchor arrives with the handshake.
CA_DEST=/usr/local/share/ca-certificates
install -d -m 0755 "$CA_DEST"

chain="$(openssl s_client -showcerts -connect "${PARROT_MAIL_HOST}:${PARROT_IMAPS_PORT}" \
    -servername "$PARROT_MAIL_HOST" </dev/null 2>/dev/null || true)"

if [[ "$chain" == *"BEGIN CERTIFICATE"* ]]; then
    # Split the chain and keep every certificate.  Installing the leaf next to
    # the CA is harmless, and it means a self-signed server certificate would
    # also work.
    printf '%s\n' "$chain" | awk -v dest="$CA_DEST" '
        /-----BEGIN CERTIFICATE-----/ { n++; out = dest "/parrot-mail-" n ".crt" }
        out { print > out }
        /-----END CERTIFICATE-----/   { close(out); out = "" }
    '
    n_certs="$(find "$CA_DEST" -name 'parrot-mail-*.crt' | wc -l)"
    update-ca-certificates >/dev/null 2>&1
    log "installed ${n_certs} certificate(s) from the server chain into the system trust store"
    for f in "$CA_DEST"/parrot-mail-*.crt; do
        log "  $(openssl x509 -noout -subject -in "$f" 2>/dev/null | sed 's/^subject=//')"
    done

    # Verify the trust store actually accepts the server now.
    if openssl s_client -connect "${PARROT_MAIL_HOST}:${PARROT_IMAPS_PORT}" \
        -servername "$PARROT_MAIL_HOST" -verify_return_error -brief </dev/null 2>&1 \
        | grep -q 'Verification: OK\|Verification error: ok'; then
        log "TLS verification against ${PARROT_MAIL_HOST} succeeds"
    else
        log "WARNING: TLS still does not verify; clients set to TLS may prompt"
    fi
else
    log "WARNING: could not read a certificate chain from ${PARROT_MAIL_HOST}:${PARROT_IMAPS_PORT}"
    log "TLS-configured clients will prompt; the default account uses no encryption anyway"
fi

# --------------------------------------------------------------------------
# Operator information
# --------------------------------------------------------------------------
# Printed so whoever is recording a macro can see the credentials and the
# anchor messages the scenario refers to, without digging through the corpus.
python3 "${HERE}/../mailserver/generate_corpus.py" --print-anchors 2>/dev/null \
    | python3 "${HERE}/print-anchors.py" \
    || log "(could not print corpus anchors)"

cat <<EOF
[client-setup] account details for the recording operator:
    IMAP      ${PARROT_MAIL_HOST}:${PARROT_IMAP_PORT} (no encryption) or ${PARROT_MAIL_HOST}:${PARROT_IMAPS_PORT} (TLS)
    SMTP      ${PARROT_MAIL_HOST}:${PARROT_SUBMISSION_PORT} (STARTTLS/plain) or ${PARROT_MAIL_HOST}:${PARROT_SMTPS_PORT} (TLS)
    username  ${PARROT_MAIL_USER}
    password  ${PARROT_MAIL_PASS}
    address   ${PARROT_MAIL_ADDRESS}
    name      ${PARROT_MAIL_REALNAME}
    security  ${PARROT_MAIL_SECURITY}
[client-setup] ready
EOF

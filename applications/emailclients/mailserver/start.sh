#!/usr/bin/env bash
# Start the benchmark mail server and prove it is serving the right mailbox.
#
# This is the runtime half of the mail container: everything here is fast, so it
# is what the prebuilt image runs on every benchmark. The slow half - installing
# packages and generating the ~500 MB corpus - is build.sh, which the image bakes
# in ahead of time.
#
# Safe to run repeatedly.
set -euo pipefail

# readlink -f, so this still resolves when the script is reached through a
# symlink: BASH_SOURCE is then the link's path and ../account.env would not
# exist next to it.  The prebuilt image relies on this - it puts start.sh on
# PATH as /usr/local/bin/parrot-mailserver-start.
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

log() { printf '[mailserver] %s\n' "$*"; }

MAIL_HOME="$(getent passwd "$PARROT_MAIL_USER" | cut -d: -f6)"
if [[ -z "$MAIL_HOME" ]]; then
    log "ERROR: user ${PARROT_MAIL_USER} does not exist - run build.sh first"
    exit 1
fi

bash "${HERE}/make-certs.sh"

# Dovecot writes its auth and LMTP sockets inside Postfix's spool.
mkdir -p /var/spool/postfix/private
postfix set-permissions >/dev/null 2>&1 || true
postfix check || true

log "starting dovecot and postfix"
dovecot
postfix start

python3 - <<'PY'
import socket, sys, time
ports = {143: 'imap', 993: 'imaps', 25: 'smtp', 587: 'submission', 465: 'smtps'}
deadline = time.monotonic() + 60
pending = dict(ports)
while pending and time.monotonic() < deadline:
    for port in list(pending):
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=2):
                print(f'[mailserver] port {port} ({pending[port]}) is up', flush=True)
                del pending[port]
        except OSError:
            pass
    if pending:
        time.sleep(1)
if pending:
    print(f'[mailserver] ports never opened: {pending}', file=sys.stderr)
    sys.exit(1)
PY

if [[ "${PARROT_SKIP_SMOKE:-0}" == "1" ]]; then
    log "skipping smoke test (PARROT_SKIP_SMOKE=1)"
else
    log "running smoke test"
    python3 "${HERE}/smoke_test.py" --host 127.0.0.1 \
        --user "$PARROT_MAIL_USER" --password "$PARROT_MAIL_PASS" \
        --manifest "${MAIL_HOME}/corpus-manifest.json" \
        --ca "${PARROT_CERT_DIR}/parrot-test-ca.crt"
fi

log "ready"

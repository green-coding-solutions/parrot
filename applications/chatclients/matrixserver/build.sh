#!/usr/bin/env bash
# Build the benchmark homeserver: install PostgreSQL and Synapse, create the
# accounts, write the configuration and seed the deterministic corpus.
#
# This is the slow half of the matrix container - most of it seeding, which
# writes tens of thousands of events through the application service.  The
# prebuilt image runs it once at build time; start.sh then does the fast
# runtime part on every benchmark.
#
# Unlike the mail server's build.sh this one does start daemons, and has to:
# Synapse's own tooling is the only way to create an account with a password,
# and the corpus can only be written through the running server's API.  Both
# are stopped again before the script returns, so the image has no state that
# depends on them still being up.
#
# ---------------------------------------------------------------------------
# THE VERSION PINS BELOW WERE RESOLVED FROM REPOSITORY METADATA, NOT FROM A
# BUILD.  Both were read out of the published Packages indexes on 2026-08-08:
# matrix-synapse-py3 from packages.matrix.org/debian noble, postgresql from the
# Ubuntu noble archive.  They are the right strings; what has NOT been proven is
# that the two install cleanly together, because no build has been run yet.
#
# PARROT_ALLOW_UNPINNED=1 installs whatever is current instead and prints the
# resolved versions at the end.  Do not benchmark from an unpinned build: it is
# the same mistake as an unpinned Flatpak branch, and no recording survives it.
# ---------------------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

PKG_SYNAPSE='1.158.0+noble1'
PKG_POSTGRES='16+257build1.1'
PG_VERSION='16'

HISTORY="${PARROT_MATRIX_HISTORY:-40000}"
PHOTOS="${PARROT_MATRIX_PHOTOS:-400}"
MEMBERS="${PARROT_MATRIX_MEMBERS:-500}"
FILLERS="${PARROT_MATRIX_FILLERS:-60}"

CONF_DIR=/etc/matrix-synapse
STATE_DIR=/var/lib/matrix-synapse
MANIFEST="${STATE_DIR}/corpus-manifest.json"

log() { printf '[matrixserver-build] %s\n' "$*"; }

pin() {
    # pin <package> <version> -> "package=version", or bare package when the
    # build is explicitly unpinned.
    if [[ "${PARROT_ALLOW_UNPINNED:-0}" == "1" ]]; then
        printf '%s' "$1"
    else
        printf '%s=%s' "$1" "$2"
    fi
}

# --------------------------------------------------------------------------
log "installing packages"
# --------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg lsb-release python3 >/dev/null

# Synapse comes from matrix.org's own repository.  Ubuntu 24.04 packages
# Synapse 1.98, which is old enough that some of the client APIs the seeder
# uses behave differently; matrix.org publishes current releases for noble.
log "adding the matrix.org repository"
curl -fsSL https://packages.matrix.org/debian/matrix-org-archive-keyring.gpg \
    -o /usr/share/keyrings/matrix-org-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/matrix-org-archive-keyring.gpg] https://packages.matrix.org/debian/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/matrix-org.list
apt-get update -qq

log "installing synapse and postgresql"
# Synapse asks for the server name interactively unless it is preseeded.
echo "matrix-synapse-py3 matrix-synapse/server-name string ${PARROT_MATRIX_DOMAIN}" | debconf-set-selections
echo "matrix-synapse-py3 matrix-synapse/report-stats boolean false" | debconf-set-selections
apt-get install -y -qq --no-install-recommends \
    "$(pin matrix-synapse-py3 "$PKG_SYNAPSE")" \
    "$(pin postgresql "$PKG_POSTGRES")" \
    postgresql-client >/dev/null

# --------------------------------------------------------------------------
log "locating the synapse interpreter"
# --------------------------------------------------------------------------
# matrix.org's package does NOT install Synapse into the system Python. It
# ships a self-contained virtualenv under /opt/venvs/matrix-synapse, so
# `python3 -m synapse.app.homeserver` fails with ModuleNotFoundError - which
# reads like a broken install rather than like the wrong interpreter.
#
# Resolved rather than hardcoded, so this keeps working if the package layout
# changes or if Synapse ever comes from somewhere else.
SYNAPSE_VENV=/opt/venvs/matrix-synapse
if [[ -x "${SYNAPSE_VENV}/bin/python" ]]; then
    SYNAPSE_PY="${SYNAPSE_VENV}/bin/python"
elif python3 -c 'import synapse' >/dev/null 2>&1; then
    SYNAPSE_PY=python3
else
    log "ERROR: cannot find a python that can import synapse"
    log "       looked for ${SYNAPSE_VENV}/bin/python and the system python3"
    exit 1
fi
log "using ${SYNAPSE_PY} ($("$SYNAPSE_PY" -c 'import synapse; print("synapse", synapse.__version__)'))"

# register_new_matrix_user likewise: the package may or may not put a wrapper
# on PATH depending on its version.
if [[ -x "${SYNAPSE_VENV}/bin/register_new_matrix_user" ]]; then
    REGISTER_BIN="${SYNAPSE_VENV}/bin/register_new_matrix_user"
elif command -v register_new_matrix_user >/dev/null 2>&1; then
    REGISTER_BIN="$(command -v register_new_matrix_user)"
else
    log "ERROR: register_new_matrix_user not found"
    exit 1
fi
log "using ${REGISTER_BIN}"

# start.sh has to make the same choice at runtime, and must not re-derive it -
# a mismatch between the interpreter that generated the keys and the one that
# serves them is the kind of thing that only shows up as a failed benchmark.
printf 'SYNAPSE_PY=%s\nREGISTER_BIN=%s\n' "$SYNAPSE_PY" "$REGISTER_BIN" \
    > /opt/parrot/synapse-paths.env

# --------------------------------------------------------------------------
log "preparing postgresql"
# --------------------------------------------------------------------------
# Synapse requires the C collation.  A database created with the container's
# default locale passes every smoke test and then produces subtly wrong
# ordering in room history, which would show up as a scrambled timeline in the
# scroll-back block and nowhere else.
pg_ctlcluster "$PG_VERSION" main start
runuser -u postgres -- psql -q -c \
    "CREATE ROLE synapse WITH LOGIN PASSWORD 'synapse';"
runuser -u postgres -- psql -q -c \
    "CREATE DATABASE synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE=template0 OWNER synapse;"

# --------------------------------------------------------------------------
log "installing synapse configuration"
# --------------------------------------------------------------------------
install -d -o matrix-synapse -g matrix-synapse "$STATE_DIR" /var/log/matrix-synapse
install -m 644 "${HERE}/conf/homeserver.yaml" "${CONF_DIR}/homeserver.yaml"
install -m 644 "${HERE}/conf/log.config" "${CONF_DIR}/log.config"
install -m 644 "${HERE}/conf/parrot-appservice.yaml" "${CONF_DIR}/parrot-appservice.yaml"

# The Debian package ships a conf.d that would override the hand-written file.
rm -f "${CONF_DIR}/conf.d/"*.yaml || true

# The signing key is the one thing that cannot be written by hand.  Federation
# is off and no other server ever verifies it, so a key generated at build time
# is fine - it just has to exist and stay put once the image is built.
if [[ ! -f "${CONF_DIR}/${PARROT_MATRIX_DOMAIN}.signing.key" ]]; then
    log "generating the signing key"
    runuser -u matrix-synapse -- "$SYNAPSE_PY" -m synapse.app.homeserver \
        --server-name "$PARROT_MATRIX_DOMAIN" \
        --config-path "${CONF_DIR}/homeserver.yaml" \
        --generate-keys
fi
chown -R matrix-synapse:matrix-synapse "$CONF_DIR" "$STATE_DIR" /var/log/matrix-synapse

# --------------------------------------------------------------------------
log "starting synapse to create accounts and seed"
# --------------------------------------------------------------------------
# --daemonize sends everything to the configured log file, so a startup failure
# leaves NOTHING on stdout and `set -e` aborts the build with no explanation at
# all. Capture both streams and dump them, plus the homeserver log, before
# giving up - a config Synapse rejects and a database it cannot reach look
# identical from out here otherwise.
synapse_failed() {
    log "ERROR: synapse did not start"
    log "--- command output ---"
    sed 's/^/    /' /tmp/synapse-start.log 2>/dev/null || true
    log "--- homeserver.log ---"
    tail -n 40 /var/log/matrix-synapse/homeserver.log 2>/dev/null | sed 's/^/    /' || \
        log "    (no homeserver.log - synapse died before opening it)"
    log "--- postgres ---"
    runuser -u postgres -- pg_isready 2>&1 | sed 's/^/    /' || true
    exit 1
}

# Backgrounded here rather than with Synapse's own --daemonize. The flag forks
# and detaches, which means the shell gets an exit status from the parent and
# NOTHING from the child that actually failed - a silent non-zero with an empty
# log, which is exactly what this script hit. Owning the process keeps stderr
# where it can be read and makes the readiness wait below the only definition
# of "started".
runuser -u matrix-synapse -- "$SYNAPSE_PY" -m synapse.app.homeserver \
    --config-path "${CONF_DIR}/homeserver.yaml" \
    >/tmp/synapse-start.log 2>&1 &
SYNAPSE_PID=$!

for _ in $(seq 120); do
    curl -fsS "http://127.0.0.1:${PARROT_MATRIX_PORT}/_matrix/client/versions" >/dev/null 2>&1 && break
    # If the process is already gone there is no point waiting out the timeout.
    kill -0 "$SYNAPSE_PID" 2>/dev/null || break
    sleep 1
done
curl -fsS "http://127.0.0.1:${PARROT_MATRIX_PORT}/_matrix/client/versions" >/dev/null || synapse_failed

# The two accounts that need real passwords, because something logs into them:
# the clients log in as @parrot, and parrot-bot.py logs in as @echo.  Everybody
# else in the corpus is spoken for by the application service and has no
# password at all.
log "creating ${PARROT_MATRIX_USER} and ${PARROT_BOT_USER}"
"$REGISTER_BIN" \
    -u "$PARROT_MATRIX_USER" -p "$PARROT_MATRIX_PASS" --no-admin \
    -c "${CONF_DIR}/homeserver.yaml" "http://127.0.0.1:${PARROT_MATRIX_PORT}"
"$REGISTER_BIN" \
    -u "$PARROT_BOT_USER" -p "$PARROT_BOT_PASS" --no-admin \
    -c "${CONF_DIR}/homeserver.yaml" "http://127.0.0.1:${PARROT_MATRIX_PORT}"

# --------------------------------------------------------------------------
log "seeding the corpus (${HISTORY} messages, ${MEMBERS} members, ${PHOTOS} images)"
# --------------------------------------------------------------------------
python3 "${HERE}/seed_corpus.py" \
    --homeserver "http://127.0.0.1:${PARROT_MATRIX_PORT}" \
    --user "$PARROT_MATRIX_USER" \
    --bot "$PARROT_BOT_USER" \
    --history "$HISTORY" \
    --photos "$PHOTOS" \
    --members "$MEMBERS" \
    --fillers "$FILLERS" \
    --manifest "$MANIFEST"
chown matrix-synapse:matrix-synapse "$MANIFEST"

# --------------------------------------------------------------------------
log "stopping daemons"
# --------------------------------------------------------------------------
# Nothing in the image may depend on these still running: GMT starts the
# container fresh and start.sh brings them up again.
pkill -f 'synapse.app.homeserver' || true
sleep 3
pg_ctlcluster "$PG_VERSION" main stop

if [[ "${PARROT_ALLOW_UNPINNED:-0}" == "1" ]]; then
    log "UNPINNED BUILD - paste these back into the pins at the top of this file:"
    log "  PKG_SYNAPSE='$(dpkg-query -W -f='${Version}' matrix-synapse-py3)'"
    log "  PKG_POSTGRES='$(dpkg-query -W -f='${Version}' postgresql)'"
fi

log "build complete - run start.sh to serve it"

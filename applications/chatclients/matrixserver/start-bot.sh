#!/usr/bin/env bash
# Start parrot-bot.py in the background and do not return until it is listening.
#
# This exists because of how GMT runs setup-commands: they are executed in
# order and each one has to *finish*.  A bot is a daemon, so it cannot be a
# setup-command directly - it would hang the run before the flow ever starts.
# And it cannot be launched from the flow either, because the flow is the single
# replay command.  So: background it here, then block until it has completed its
# initial sync, so the replay cannot start before the bot is able to hear a
# trigger.
#
# The wait is the point.  Without it the run still comes up, the client still
# types `drip`, and the bot misses it because it was still logging in - which
# shows up as a checkpoint mismatch two minutes later and looks like a client
# bug rather than a startup race.
#
# Safe to run repeatedly: an already-running bot is left alone.
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../account.env
source "${HERE}/../account.env"

READY_FILE=/run/parrot-bot.ready
LOG_FILE=/var/log/parrot-bot.log
READY_TIMEOUT=${PARROT_BOT_READY_TIMEOUT:-120}

# LOCALHOST, not PARROT_MATRIX_URL.
#
# PARROT_MATRIX_URL is the CLIENT-facing address - `matrix.parrot.test`, a
# Docker network alias that exists for the other containers on the benchmark
# network. The bot runs inside the homeserver container itself, where that name
# need not resolve at all: it does not on the default bridge, so a standalone
# `docker run` of this image (which is what `make check-matrixserver` does)
# fails with "never answered" and looks like the server is broken rather than
# like the bot is dialling the wrong number.
#
# The homeserver is always on loopback from in here, so that is what to use.
BOT_HOMESERVER="${PARROT_BOT_HOMESERVER:-http://127.0.0.1:${PARROT_MATRIX_PORT}}"

log() { printf '[parrot-bot] %s\n' "$*"; }

# Print everything a post-mortem needs, because there will be no post-mortem.
#
# GMT deletes the container as soon as a setup-command exits non-zero, so any
# log file not copied to stderr here is gone before anyone reads the run. The
# bot's own log says what failed; when what failed is the homeserver answering
# 500, only Synapse's log says why, and that log stays inside the container.
dump_diagnostics() {
    printf -- '--- tail of %s ---\n' "$LOG_FILE" >&2
    tail -n 40 "$LOG_FILE" >&2 || true
    local file
    for file in /var/log/matrix-synapse/homeserver.log \
                /var/log/matrix-synapse/start.log; do
        [[ -f "$file" ]] || continue
        printf -- '--- tail of %s ---\n' "$file" >&2
        tail -n 40 "$file" >&2 || true
    done
}

if pgrep -f 'parrot-bot\.py' >/dev/null 2>&1; then
    log "already running"
    exit 0
fi

rm -f "$READY_FILE"

log "starting, logging to ${LOG_FILE}"
nohup python3 "${HERE}/parrot-bot.py" \
    --homeserver "${BOT_HOMESERVER}" \
    --user "${PARROT_BOT_USER}" \
    --password "${PARROT_BOT_PASS}" \
    --count "${PARROT_BOT_DRIP_COUNT}" \
    --interval "${PARROT_BOT_DRIP_INTERVAL}" \
    --ready-file "$READY_FILE" \
    >>"$LOG_FILE" 2>&1 &
BOT_PID=$!

# LIVENESS IS CHECKED BY PID, NOT BY `pgrep -f`.
#
# It was pgrep, and that is a race: while the kernel is exec'ing python3 over
# the forked shell, /proc/<pid>/cmdline is briefly EMPTY, so `pgrep -f
# 'parrot-bot\.py'` matches nothing and this loop concludes the bot has exited.
# Measured once on a freshly built pair of containers - the setup aborted with
# "ERROR: bot exited during startup" while the bot went on to log in and sync
# perfectly well a second later, leaving a log that contradicts the error.
#
# It reproduces roughly never (three forced restarts in a warm container all
# passed), which is exactly what makes it expensive: it fails one rebuild in
# several, and each one it fails costs a whole recording or GMT run.
#
# $! cannot have this problem. The PID is the process this script started,
# whatever its cmdline happens to look like at the instant it is sampled.
deadline=$((SECONDS + READY_TIMEOUT))
while [[ ! -f "$READY_FILE" ]]; do
    if ! kill -0 "$BOT_PID" 2>/dev/null; then
        log "ERROR: bot exited during startup"
        dump_diagnostics
        exit 1
    fi
    if (( SECONDS >= deadline )); then
        log "ERROR: bot did not become ready within ${READY_TIMEOUT}s"
        dump_diagnostics
        exit 1
    fi
    sleep 1
done

log "ready as $(cat "$READY_FILE")"
